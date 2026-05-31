package net.joker1007.bookwall.data.opds

import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.kxml2.io.KXmlParser
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream

class OpdsRepositoryTest {

    private lateinit var server: MockWebServer
    private lateinit var repository: OpdsRepository

    /** FeedParser backed by kxml2 so it runs off-device (no android.util.Xml). */
    private val feedParser = object : FeedParser {
        private val core = OpdsParser()
        override fun parse(input: InputStream): OpdsFeed {
            val pull = KXmlParser().apply {
                setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
                setInput(input, "UTF-8")
            }
            return core.parse(pull)
        }
    }

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        repository = OpdsRepository(OkHttpClientFactory(OkHttpClient()), feedParser)
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun server() = OpdsServer(name = "t", baseUrl = server.url("/opds").toString())

    @Test
    fun `fetchFeed parses a successful response`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(FEED))

        val result = repository.fetchFeed(server(), server.url("/opds").toString())

        assertTrue(result is FeedResult.Success)
        assertEquals("Bookwall", (result as FeedResult.Success).feed.title)
    }

    @Test
    fun `fetchFeed maps 401 to AuthFailed`() = runTest {
        server.enqueue(MockResponse().setResponseCode(401))
        assertEquals(FeedResult.AuthFailed, repository.fetchFeed(server(), server.url("/opds").toString()))
    }

    @Test
    fun `fetchFeed maps 500 to HttpError`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500))
        assertEquals(FeedResult.HttpError(500), repository.fetchFeed(server(), server.url("/opds").toString()))
    }

    @Test
    fun `resolveOpdsHref resolves absolute path against base`() {
        val resolved = resolveOpdsHref("https://host/opds", "/opds/books/42/file.cbz")
        assertEquals("https://host/opds/books/42/file.cbz", resolved)
    }

    private companion object {
        val FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <title>Bookwall</title>
              <id>urn:bookwall:root</id>
              <link rel="self" href="/opds" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              <entry>
                <title>Recent</title>
                <id>urn:bookwall:nav:Recent</id>
                <link rel="subsection" href="/opds/recent" type="application/atom+xml"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
