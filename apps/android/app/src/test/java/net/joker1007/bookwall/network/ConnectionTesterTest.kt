package net.joker1007.bookwall.network

import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ConnectionTesterTest {

    private lateinit var server: MockWebServer
    private lateinit var tester: ConnectionTester

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        tester = ConnectionTester(OkHttpClientFactory(OkHttpClient()))
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun serverAt(path: String = "/opds", auth: AuthType = AuthType.NONE) = OpdsServer(
        name = "test",
        baseUrl = server.url(path).toString(),
        authType = auth,
        username = if (auth == AuthType.BASIC) "user" else null,
        password = if (auth == AuthType.BASIC) "pass" else null,
    )

    @Test
    fun `2xx response yields Success`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200))
        assertEquals(ConnectionResult.Success(200), tester.test(serverAt()))
    }

    @Test
    fun `401 yields AuthFailed`() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        assertEquals(ConnectionResult.AuthFailed, tester.test(serverAt()))
    }

    @Test
    fun `500 yields HttpError`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500))
        assertEquals(ConnectionResult.HttpError(500), tester.test(serverAt()))
    }

    @Test
    fun `malformed url yields InvalidUrl`() = runTest {
        val result = tester.test(OpdsServer(name = "x", baseUrl = "not a url"))
        assertEquals(ConnectionResult.InvalidUrl, result)
    }

    @Test
    fun `basic auth adds Authorization header`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200))
        tester.test(serverAt(auth = AuthType.BASIC))

        val recorded = server.takeRequest()
        val header = recorded.getHeader("Authorization")
        assertTrue(header != null && header.startsWith("Basic "))
    }
}
