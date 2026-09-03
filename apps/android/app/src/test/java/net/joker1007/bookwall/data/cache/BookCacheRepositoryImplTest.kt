package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.FakeCachedBookDao
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.PseInfo
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class BookCacheRepositoryImplTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val dao = FakeCachedBookDao()
    private val scheduler = FakeScheduler()
    private var now = 1_000L
    private val settings = MutableStateFlow(CacheSettings())

    private class FakeScheduler : CacheDownloadScheduler {
        var scheduled = 0
        var rescheduled = 0
        var lastWifiOnly: Boolean? = null

        override fun schedule(wifiOnly: Boolean) {
            scheduled++
            lastWifiOnly = wifiOnly
        }

        override fun reschedule(wifiOnly: Boolean) {
            rescheduled++
            lastWifiOnly = wifiOnly
        }
    }

    private class FakeSettingsRepository(
        private val flow: MutableStateFlow<CacheSettings>,
    ) : CacheSettingsRepository {
        override val settings = flow

        override suspend fun setWifiOnly(value: Boolean) = Unit

        override suspend fun setAutoCacheOnRead(value: Boolean) = Unit

        override suspend fun setMaxCacheBytes(value: Long) = Unit
    }

    private fun repository(): BookCacheRepositoryImpl = BookCacheRepositoryImpl(
        dao = dao,
        fileStore = BookCacheFileStore(tmp.root),
        settingsRepository = FakeSettingsRepository(settings),
        scheduler = scheduler,
        clock = { now },
        ioDispatcher = UnconfinedTestDispatcher(),
    )

    private val server = OpdsServer(
        id = 1L,
        name = "Test",
        baseUrl = "https://example.com/opds",
        authType = AuthType.NONE,
        username = null,
        password = null,
        allowSelfSignedCert = false,
    )

    private fun book(id: Long, size: Long? = 42L) = OpdsEntry.Book(
        title = "Book $id",
        id = "urn:bookwall:book:$id",
        authors = listOf("Author A", "Author B"),
        acquisitionHref = "/opds/books/$id/file.cbz",
        acquisitionType = "application/x-cbz",
        thumbnailHref = "/rails/rep/thumb$id.jpg",
        fileSize = size,
        pse = PseInfo(streamHrefTemplate = "/opds/books/$id/pages/{pageNumber}", pageCount = 120),
    )

    private suspend fun insertCompleted(repo: BookCacheRepositoryImpl, id: Long, bytes: Long, accessedAt: Long) {
        val store = BookCacheFileStore(tmp.root)
        val fileName = store.bookFileName(1L, id, "application/x-cbz")
        store.fileFor(fileName).writeBytes(ByteArray(bytes.toInt()))
        dao.upsert(
            CachedBookEntity(
                serverId = 1L,
                bookId = id,
                title = "Book $id",
                authors = "",
                format = "application/x-cbz",
                pageCount = 0,
                fileName = fileName,
                thumbnailFileName = null,
                status = CachedBookStatus.COMPLETED,
                downloadedBytes = bytes,
                totalBytes = bytes,
                retryCount = 0,
                acquisitionUrl = "https://example.com/opds/books/$id/file.cbz",
                thumbnailUrl = null,
                createdAt = accessedAt,
                lastAccessedAt = accessedAt,
            ),
        )
    }

    @Test
    fun `enqueue inserts a pending row with resolved urls and schedules work`() = runTest {
        val repo = repository()
        repo.enqueue(server, book(42L))

        val row = dao.find(1L, 42L)
        assertNotNull(row)
        row!!
        assertEquals(CachedBookStatus.PENDING, row.status)
        assertEquals("https://example.com/opds/books/42/file.cbz", row.acquisitionUrl)
        assertEquals("https://example.com/rails/rep/thumb42.jpg", row.thumbnailUrl)
        assertEquals(42L, row.totalBytes)
        assertEquals(120, row.pageCount)
        assertEquals("Author A, Author B", row.authors)
        assertEquals("1/42.cbz", row.fileName)
        assertEquals(1, scheduler.scheduled)
        assertEquals(true, scheduler.lastWifiOnly)
    }

    @Test
    fun `enqueue is a no-op when a row already exists`() = runTest {
        val repo = repository()
        repo.enqueue(server, book(42L))
        repo.enqueue(server, book(42L))

        assertEquals(1, dao.rows.value.size)
        assertEquals(1, scheduler.scheduled)
    }

    @Test
    fun `cachedFile returns the completed file and bumps its lru timestamp`() = runTest {
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)
        now = 5_000L

        val file = repo.cachedFile(1L, 1L)

        assertNotNull(file)
        assertTrue(file!!.exists())
        assertEquals(5_000L, dao.find(1L, 1L)!!.lastAccessedAt)
    }

    @Test
    fun `cachedFile drops the row when the file has vanished`() = runTest {
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)
        BookCacheFileStore(tmp.root).fileFor(dao.find(1L, 1L)!!.fileName).delete()

        assertNull(repo.cachedFile(1L, 1L))
        assertNull(dao.find(1L, 1L))
    }

    @Test
    fun `cachedFile ignores rows that are not completed`() = runTest {
        val repo = repository()
        repo.enqueue(server, book(42L))

        assertNull(repo.cachedFile(1L, 42L))
    }

    @Test
    fun `enforceLimit evicts least recently opened books first`() = runTest {
        settings.value = CacheSettings(maxCacheBytes = 25)
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L) // oldest
        insertCompleted(repo, 2L, bytes = 10, accessedAt = 200L)
        insertCompleted(repo, 3L, bytes = 10, accessedAt = 300L) // newest

        repo.enforceLimit()

        assertNull(dao.find(1L, 1L))
        assertNotNull(dao.find(1L, 2L))
        assertNotNull(dao.find(1L, 3L))
        assertFalse(BookCacheFileStore(tmp.root).fileFor("1/1.cbz").exists())
    }

    @Test
    fun `enforceLimit does nothing when unlimited`() = runTest {
        settings.value = CacheSettings(maxCacheBytes = 0)
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)

        repo.enforceLimit()

        assertNotNull(dao.find(1L, 1L))
    }

    @Test
    fun `delete removes the row and its files`() = runTest {
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)

        repo.delete(1L, 1L)

        assertNull(dao.find(1L, 1L))
        assertFalse(BookCacheFileStore(tmp.root).fileFor("1/1.cbz").exists())
    }

    @Test
    fun `deleteAll clears every row and file`() = runTest {
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)
        insertCompleted(repo, 2L, bytes = 10, accessedAt = 200L)

        repo.deleteAll()

        assertTrue(dao.rows.value.isEmpty())
        assertFalse(BookCacheFileStore(tmp.root).fileFor("1/1.cbz").exists())
        assertFalse(BookCacheFileStore(tmp.root).fileFor("1/2.cbz").exists())
    }

    @Test
    fun `reconcile requeues interrupted downloads keeping their part file`() = runTest {
        val repo = repository()
        repo.enqueue(server, book(42L))
        dao.updateStatus(1L, 42L, CachedBookStatus.DOWNLOADING)
        val part = BookCacheFileStore(tmp.root).partFileFor(dao.find(1L, 42L)!!.fileName)
        part.writeBytes(ByteArray(5))
        scheduler.scheduled = 0

        repo.reconcile()

        val row = dao.find(1L, 42L)!!
        assertEquals(CachedBookStatus.PENDING, row.status)
        assertEquals(5L, row.downloadedBytes)
        assertTrue(part.exists())
        assertEquals(1, scheduler.scheduled)
    }

    @Test
    fun `reconcile drops completed rows whose file is missing and orphan files`() = runTest {
        val repo = repository()
        insertCompleted(repo, 1L, bytes = 10, accessedAt = 100L)
        val store = BookCacheFileStore(tmp.root)
        store.fileFor("1/1.cbz").delete()
        val orphan = store.fileFor("9/9.cbz").apply { writeBytes(ByteArray(3)) }

        repo.reconcile()

        assertNull(dao.find(1L, 1L))
        assertFalse(orphan.exists())
    }

    @Test
    fun `adoptFile registers an existing download as completed`() = runTest {
        val repo = repository()
        val source = tmp.newFile("downloaded.epub").apply { writeBytes(ByteArray(7)) }
        val epub = OpdsEntry.Book(
            title = "Epub",
            id = "urn:bookwall:book:7",
            acquisitionHref = "/opds/books/7/file.epub",
            acquisitionType = "application/epub+zip",
        )

        repo.adoptFile(server, epub, source)

        val row = dao.find(1L, 7L)
        assertNotNull(row)
        assertEquals(CachedBookStatus.COMPLETED, row!!.status)
        assertEquals(7L, row.downloadedBytes)
        assertTrue(BookCacheFileStore(tmp.root).fileFor("1/7.epub").exists())
    }

    @Test
    fun `rescheduleDownloads cancels and re-registers with current constraints`() = runTest {
        settings.value = CacheSettings(wifiOnly = false)
        val repo = repository()

        repo.rescheduleDownloads()

        assertEquals(1, scheduler.rescheduled)
        assertEquals(false, scheduler.lastWifiOnly)
    }
}
