package net.joker1007.bookwall.data.cache

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.ListenableWorker
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import androidx.work.testing.TestListenableWorkerBuilder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import net.joker1007.bookwall.data.db.BookwallDatabase
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import javax.inject.Provider

@RunWith(AndroidJUnit4::class)
class BookCacheDownloadWorkerTest {

    private lateinit var context: Context
    private lateinit var db: BookwallDatabase
    private lateinit var server: MockWebServer
    private lateinit var fileStore: BookCacheFileStore

    private val opdsServer = OpdsServer(id = 1L, name = "Test", baseUrl = "http://localhost/")

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        db = Room.inMemoryDatabaseBuilder(context, BookwallDatabase::class.java).build()
        fileStore = BookCacheFileStore(File(context.cacheDir, "worker_test_${System.nanoTime()}"))
        server = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        server.shutdown()
        db.close()
        fileStore.root.deleteRecursively()
    }

    private fun buildWorker(): BookCacheDownloadWorker {
        val dao = db.cachedBookDao()
        val serverRepository = object : ServerRepository {
            override fun observeServers(): Flow<List<OpdsServer>> = MutableStateFlow(listOf(opdsServer))

            override suspend fun getServer(id: Long): OpdsServer? = opdsServer.takeIf { it.id == id }

            override suspend fun upsert(server: OpdsServer): Long = server.id

            override suspend fun setSyncProgressTemplate(id: Long, template: String?) = Unit

            override suspend fun delete(id: Long) = Unit
        }
        val settings = object : CacheSettingsRepository {
            override val settings: Flow<CacheSettings> = MutableStateFlow(CacheSettings(maxCacheBytes = 0))

            override suspend fun setWifiOnly(value: Boolean) = Unit

            override suspend fun setAutoCacheOnRead(value: Boolean) = Unit

            override suspend fun setMaxCacheBytes(value: Long) = Unit
        }
        val scheduler = object : CacheDownloadScheduler {
            override fun schedule(wifiOnly: Boolean) = Unit

            override fun reschedule(wifiOnly: Boolean) = Unit
        }
        val repository = BookCacheRepositoryImpl(
            dao = dao,
            fileStore = fileStore,
            settingsRepository = settings,
            scheduler = scheduler,
            clock = { System.currentTimeMillis() },
            ioDispatcher = Dispatchers.IO,
        )
        val factory = object : WorkerFactory() {
            override fun createWorker(
                appContext: Context,
                workerClassName: String,
                workerParameters: WorkerParameters,
            ): ListenableWorker = BookCacheDownloadWorker(
                context = appContext,
                params = workerParameters,
                dao = dao,
                fileStore = fileStore,
                serverRepository = serverRepository,
                clientFactory = OkHttpClientFactory(OkHttpClient()),
                repository = Provider { repository },
                clock = { System.currentTimeMillis() },
                ioDispatcher = Dispatchers.IO,
            )
        }
        return TestListenableWorkerBuilder<BookCacheDownloadWorker>(context)
            .setWorkerFactory(factory)
            .build() as BookCacheDownloadWorker
    }

    private fun pendingRow(bookId: Long, path: String, thumbPath: String? = null) = CachedBookEntity(
        serverId = 1L,
        bookId = bookId,
        title = "Book $bookId",
        authors = "Author",
        format = "application/x-cbz",
        pageCount = 10,
        fileName = fileStore.bookFileName(1L, bookId, "application/x-cbz"),
        thumbnailFileName = null,
        status = CachedBookStatus.PENDING,
        downloadedBytes = 0,
        totalBytes = 0,
        retryCount = 0,
        acquisitionUrl = server.url(path).toString(),
        thumbnailUrl = thumbPath?.let { server.url(it).toString() },
        createdAt = System.currentTimeMillis(),
        lastAccessedAt = System.currentTimeMillis(),
    )

    @Test
    fun downloadsPendingBooksAndMarksThemCompleted() = runBlocking {
        val bookBytes = ByteArray(256 * 1024) { it.toByte() }
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when (request.path) {
                "/books/1/file.cbz" -> MockResponse().setResponseCode(200)
                    .setBody(okio.Buffer().write(bookBytes))
                "/thumbs/1.jpg" -> MockResponse().setResponseCode(200)
                    .setBody(okio.Buffer().write(ByteArray(16)))
                else -> MockResponse().setResponseCode(404)
            }
        }
        db.cachedBookDao().upsert(pendingRow(1L, "/books/1/file.cbz", "/thumbs/1.jpg"))

        val result = buildWorker().doWork()

        assertEquals(ListenableWorker.Result.success(), result)
        val row = db.cachedBookDao().find(1L, 1L)
        assertNotNull(row)
        assertEquals(CachedBookStatus.COMPLETED, row!!.status)
        assertEquals(bookBytes.size.toLong(), row.downloadedBytes)
        val file = fileStore.fileFor(row.fileName)
        assertTrue(file.exists())
        assertEquals(bookBytes.size.toLong(), file.length())
        assertNotNull(row.thumbnailFileName)
        assertTrue(fileStore.fileFor(row.thumbnailFileName!!).exists())
        assertFalse(fileStore.partFileFor(row.fileName).exists())
    }

    @Test
    fun marksTheBookFailedAfterRepeatedHttpErrors() = runBlocking {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse =
                MockResponse().setResponseCode(500)
        }
        db.cachedBookDao().upsert(pendingRow(2L, "/books/2/file.cbz"))

        val result = buildWorker().doWork()

        assertEquals(ListenableWorker.Result.success(), result)
        val row = db.cachedBookDao().find(1L, 2L)
        assertEquals(CachedBookStatus.FAILED, row!!.status)
        assertEquals(3, row.retryCount)
        assertFalse(fileStore.fileFor(row.fileName).exists())
    }

    @Test
    fun drainsMultiplePendingRowsInOneRun() = runBlocking {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = when {
                request.path!!.endsWith(".cbz") -> MockResponse().setResponseCode(200)
                    .setBody(okio.Buffer().write(ByteArray(64)))
                else -> MockResponse().setResponseCode(404)
            }
        }
        db.cachedBookDao().upsert(pendingRow(3L, "/books/3/file.cbz"))
        db.cachedBookDao().upsert(pendingRow(4L, "/books/4/file.cbz"))

        buildWorker().doWork()

        assertEquals(CachedBookStatus.COMPLETED, db.cachedBookDao().find(1L, 3L)!!.status)
        assertEquals(CachedBookStatus.COMPLETED, db.cachedBookDao().find(1L, 4L)!!.status)
    }
}
