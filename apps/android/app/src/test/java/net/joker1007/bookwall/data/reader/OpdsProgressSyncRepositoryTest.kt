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
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

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
