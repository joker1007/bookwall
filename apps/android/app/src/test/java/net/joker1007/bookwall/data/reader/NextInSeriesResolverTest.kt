package net.joker1007.bookwall.data.reader

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.MainDispatcherRule
import net.joker1007.bookwall.data.opds.FeedParser
import net.joker1007.bookwall.data.opds.OpdsFeed
import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.opds.OpdsRepository
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.kxml2.io.KXmlParser
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream

@OptIn(ExperimentalCoroutinesApi::class)
class NextInSeriesResolverTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var server: MockWebServer

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

    private lateinit var resolver: NextInSeriesResolver

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
        val repo = OpdsRepository(OkHttpClientFactory(OkHttpClient()), feedParser, mainDispatcherRule.dispatcher)
        resolver = NextInSeriesResolver(repo)
    }

    @After
    fun tearDown() = server.shutdown()

    private fun opdsServer() = OpdsServer(
        name = "s",
        baseUrl = server.url("/opds").toString(),
        authType = AuthType.NONE,
    )

    @Test
    fun `returns null without a series href`() = runTest {
        assertNull(resolver.resolve(opdsServer(), null, 7L))
        assertNull(resolver.resolve(opdsServer(), "", 7L))
    }

    @Test
    fun `returns the volume after the current book`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(SERIES_FEED))

        val next = resolver.resolve(opdsServer(), "/opds/series/1", 7L)

        assertEquals("Vol 8", next?.title)
        assertEquals("urn:bookwall:book:8", next?.id)
    }

    @Test
    fun `returns null for the last volume`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(SERIES_FEED))

        assertNull(resolver.resolve(opdsServer(), "/opds/series/1", 8L))
    }

    @Test
    fun `returns null when the current book is absent from the feed`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(SERIES_FEED))

        assertNull(resolver.resolve(opdsServer(), "/opds/series/1", 999L))
    }

    @Test
    fun `returns null when the fetch fails`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500))

        assertNull(resolver.resolve(opdsServer(), "/opds/series/1", 7L))
    }

    private companion object {
        val SERIES_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>Series 1</title>
              <id>urn:bookwall:series:1</id>
              <updated>2026-01-01T00:00:00Z</updated>
              <link rel="self" href="/opds/series/1" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
              <entry>
                <title>Vol 7</title>
                <id>urn:bookwall:book:7</id>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/7/file.cbz" type="application/vnd.comicbook+zip"/>
                <pse:link rel="http://vaemendis.net/opds-pse/stream" href="/opds/books/7/pages/{pageNumber}" type="image/jpeg" pse:count="10"/>
              </entry>
              <entry>
                <title>Vol 8</title>
                <id>urn:bookwall:book:8</id>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/8/file.cbz" type="application/vnd.comicbook+zip"/>
                <pse:link rel="http://vaemendis.net/opds-pse/stream" href="/opds/books/8/pages/{pageNumber}" type="image/jpeg" pse:count="10"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
