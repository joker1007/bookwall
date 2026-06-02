package net.joker1007.bookwall.data.reader

import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.json.JSONObject

class OpdsProgressSyncRepositoryTest {

    private lateinit var server: MockWebServer
    private lateinit var repository: OpdsProgressSyncRepository

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        repository = OpdsProgressSyncRepository(OkHttpClientFactory(OkHttpClient()))
    }

    @After
    fun tearDown() = server.shutdown()

    private fun syncServer() = OpdsServer(
        id = 1,
        name = "t",
        baseUrl = server.url("/opds").toString(),
        syncProgressTemplate = "/opds/books/{bookId}/progress",
    )

    @Test
    fun `PUTs current page to the resolved per-book endpoint`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody("{}"))

        val ok = repository.pushPageProgress(syncServer(), bookId = 42, page = 7, pageCount = 100)

        assertTrue(ok)
        val request = server.takeRequest()
        assertEquals("PUT", request.method)
        assertEquals("/opds/books/42/progress", request.path)
        assertEquals("""{"current_page":7}""", request.body.readUtf8())
    }

    @Test
    fun `PUTs EPUB cfi and fraction`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody("{}"))

        val ok = repository.pushEpubProgress(syncServer(), bookId = 42, cfi = "epubcfi(/6/4!/2)", fraction = 0.4f)

        assertTrue(ok)
        val request = server.takeRequest()
        assertEquals("PUT", request.method)
        assertEquals("/opds/books/42/progress", request.path)
        val body = JSONObject(request.body.readUtf8())
        assertEquals("epubcfi(/6/4!/2)", body.getString("epub_cfi"))
        assertEquals(0.4, body.getDouble("progress_fraction"), 0.001)
    }

    @Test
    fun `pulls EPUB progress`() = runTest {
        server.enqueue(
            MockResponse().setResponseCode(200)
                .setBody("""{"current_page":0,"epub_cfi":"epubcfi(/6/4!/2)","progress_fraction":0.6}"""),
        )

        val remote = repository.pullEpubProgress(syncServer(), bookId = 42)

        assertEquals("epubcfi(/6/4!/2)", remote?.cfi)
        assertEquals(0.6f, remote?.fraction)
        assertEquals("/opds/books/42/progress", server.takeRequest().path)
    }

    @Test
    fun `pull returns null when unsupported`() = runTest {
        val plain = OpdsServer(id = 1, name = "t", baseUrl = server.url("/opds").toString())
        assertNull(repository.pullEpubProgress(plain, bookId = 42))
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `is a no-op when the server has no sync template`() = runTest {
        val plain = OpdsServer(id = 1, name = "t", baseUrl = server.url("/opds").toString())

        val ok = repository.pushPageProgress(plain, bookId = 42, page = 7, pageCount = 100)

        assertFalse(ok)
        assertEquals(0, server.requestCount)
    }

    @Test
    fun `returns false on a server error`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500))

        val ok = repository.pushPageProgress(syncServer(), bookId = 42, page = 1, pageCount = 10)

        assertFalse(ok)
    }
}
