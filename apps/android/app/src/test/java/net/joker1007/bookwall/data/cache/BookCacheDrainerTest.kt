package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.FakeCachedBookDao
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
import okhttp3.mockwebserver.SocketPolicy
import okio.Buffer
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import javax.inject.Provider

@OptIn(ExperimentalCoroutinesApi::class)
class BookCacheDrainerTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val dao = FakeCachedBookDao()
    private lateinit var fileStore: BookCacheFileStore
    private lateinit var server: MockWebServer
    private val bookBytes = ByteArray(200 * 1024) { it.toByte() }
    private val requests = mutableListOf<RecordedRequest>()

    private val opdsServer = OpdsServer(id = 1L, name = "Test", baseUrl = "http://localhost/")

    @Before
    fun setUp() {
        fileStore = BookCacheFileStore(tmp.root)
        server = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun drainer(): BookCacheDrainer {
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
            ioDispatcher = UnconfinedTestDispatcher(),
        )
        return BookCacheDrainer(
            dao = dao,
            fileStore = fileStore,
            serverRepository = serverRepository,
            clientFactory = OkHttpClientFactory(OkHttpClient()),
            repository = Provider { repository },
            clock = { System.currentTimeMillis() },
        )
    }

    private fun pendingRow(bookId: Long = 1L, etag: String? = null) = CachedBookEntity(
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
        acquisitionUrl = server.url("/books/$bookId/file.cbz").toString(),
        thumbnailUrl = null,
        createdAt = 1L,
        lastAccessedAt = 1L,
        etag = etag,
    )

    /** Full body on the first request, cut off half way; then the handler decides. */
    private fun dispatch(onResume: (RecordedRequest) -> MockResponse) {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                requests += request
                return if (requests.size == 1) {
                    MockResponse().setResponseCode(200)
                        .setHeader("ETag", "\"v1\"")
                        .setBody(Buffer().write(bookBytes))
                        .setSocketPolicy(SocketPolicy.DISCONNECT_DURING_RESPONSE_BODY)
                } else {
                    onResume(request)
                }
            }
        }
    }

    private fun partialResponse(request: RecordedRequest): MockResponse {
        val offset = request.getHeader("Range")!!.removePrefix("bytes=").removeSuffix("-").toLong()
        return MockResponse().setResponseCode(206)
            .setHeader("ETag", "\"v1\"")
            .setHeader("Content-Range", "bytes $offset-${bookBytes.size - 1}/${bookBytes.size}")
            .setBody(Buffer().write(bookBytes, offset.toInt(), bookBytes.size - offset.toInt()))
    }

    private fun cachedBytes(row: CachedBookEntity): ByteArray = fileStore.fileFor(row.fileName).readBytes()

    @Test
    fun `resumes an interrupted download with Range and If-Range`() = runTest {
        dispatch(::partialResponse)
        dao.upsert(pendingRow())

        drainer().drain()

        val row = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.COMPLETED, row.status)
        assertEquals(0, row.retryCount)
        assertEquals(2, requests.size)
        val offset = requests[1].getHeader("Range")!!.removePrefix("bytes=").removeSuffix("-").toLong()
        assertEquals(bookBytes.size / 2L, offset)
        assertEquals("\"v1\"", requests[1].getHeader("If-Range"))
        assertArrayEquals(bookBytes, cachedBytes(row))
        assertFalse(fileStore.partFileFor(row.fileName).exists())
    }

    @Test
    fun `starts over when the server answers a Range request with the whole file`() = runTest {
        dispatch {
            MockResponse().setResponseCode(200).setHeader("ETag", "\"v2\"").setBody(Buffer().write(bookBytes))
        }
        dao.upsert(pendingRow())

        drainer().drain()

        val row = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.COMPLETED, row.status)
        assertEquals("\"v2\"", row.etag)
        assertArrayEquals(bookBytes, cachedBytes(row))
    }

    @Test
    fun `rejects a partial response that does not continue where the part file ends`() = runTest {
        dispatch { request ->
            when (requests.size) {
                2 -> MockResponse().setResponseCode(206)
                    .setHeader("Content-Range", "bytes 0-${bookBytes.size - 1}/${bookBytes.size}")
                    .setBody(Buffer().write(bookBytes))
                else -> partialResponse(request)
            }
        }
        dao.upsert(pendingRow())

        drainer().drain()

        val row = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.COMPLETED, row.status)
        assertEquals(1, row.retryCount)
        assertArrayEquals(bookBytes, cachedBytes(row))
    }

    @Test
    fun `restarts from scratch after a 416`() = runTest {
        dispatch { request ->
            if (requests.size == 2) {
                MockResponse().setResponseCode(416).setHeader("Content-Range", "bytes */${bookBytes.size}")
            } else {
                assertNull(request.getHeader("Range"))
                MockResponse().setResponseCode(200).setBody(Buffer().write(bookBytes))
            }
        }
        dao.upsert(pendingRow())

        drainer().drain()

        val row = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.COMPLETED, row.status)
        assertArrayEquals(bookBytes, cachedBytes(row))
    }

    @Test
    fun `gives up only after attempts that made no progress`() = runTest {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                requests += request
                return MockResponse().setResponseCode(500)
            }
        }
        dao.upsert(pendingRow())

        drainer().drain()

        val row = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.FAILED, row.status)
        assertEquals(3, row.retryCount)
        assertEquals(3, requests.size)
        assertFalse(fileStore.partFileFor(row.fileName).exists())
    }

    @Test
    fun `resumes a part file left by a killed worker`() = runTest {
        val row = pendingRow(etag = "\"v1\"").copy(status = CachedBookStatus.DOWNLOADING)
        val half = bookBytes.size / 2
        fileStore.partFileFor(row.fileName).writeBytes(bookBytes.copyOf(half))
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                requests += request
                return partialResponse(request)
            }
        }
        dao.upsert(row)

        drainer().drain()

        assertEquals(1, requests.size)
        assertEquals("bytes=$half-", requests[0].getHeader("Range"))
        assertEquals("\"v1\"", requests[0].getHeader("If-Range"))
        val done = dao.find(1L, 1L)!!
        assertEquals(CachedBookStatus.COMPLETED, done.status)
        assertArrayEquals(bookBytes, cachedBytes(done))
    }
}
