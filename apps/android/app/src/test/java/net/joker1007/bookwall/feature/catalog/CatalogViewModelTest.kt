package net.joker1007.bookwall.feature.catalog

import androidx.lifecycle.SavedStateHandle
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.MainDispatcherRule
import net.joker1007.bookwall.data.FakeOpdsServerDao
import net.joker1007.bookwall.data.FakeSecretCipher
import net.joker1007.bookwall.data.epub.EpubDownloader
import net.joker1007.bookwall.data.FakeEpubProgressDao
import net.joker1007.bookwall.data.FakeReaderStateRepository
import net.joker1007.bookwall.data.epub.EpubProgressRepository
import java.io.File
import net.joker1007.bookwall.data.opds.FeedParser
import net.joker1007.bookwall.data.opds.OpdsFeed
import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.opds.OpdsRepository
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.kxml2.io.KXmlParser
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream

@OptIn(ExperimentalCoroutinesApi::class)
class CatalogViewModelTest {

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

    @Before
    fun setUp() {
        server = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private suspend fun viewModelForServer(): CatalogViewModel {
        val dao = FakeOpdsServerDao()
        val serverRepo = ServerRepositoryImpl(dao, FakeSecretCipher(), clock = { 0L })
        val id = serverRepo.upsert(OpdsServer(name = "s", baseUrl = server.url("/opds").toString()))
        val opdsRepo = OpdsRepository(OkHttpClientFactory(OkHttpClient()), feedParser, mainDispatcherRule.dispatcher)
        val handle = SavedStateHandle(mapOf(CatalogViewModel.ARG_SERVER_ID to id, CatalogViewModel.ARG_FEED_URL to ""))
        val epubDownloader = EpubDownloader { _, _ -> File("unused.epub") }
        val epubProgressRepo = EpubProgressRepository(FakeEpubProgressDao(), clock = { 0L })
        return CatalogViewModel(
            serverRepo, opdsRepo, { null }, epubDownloader,
            FakeReaderStateRepository(), epubProgressRepo, handle,
        )
    }

    @Test
    fun `loads acquisition feed and splits books`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.loading)
        assertEquals(2, state.books.size)
        // default TITLE sort: "Aaa" before "Zzz"
        assertEquals("Aaa Book", state.books.first().title)
    }

    @Test
    fun `sort by author reorders books`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()
        vm.setSort(BookSort.AUTHOR, SortDirection.ASC)

        assertEquals("Zzz Book", vm.state.value.books.first().title)
    }

    @Test
    fun `sort by added date respects direction`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        vm.setSort(BookSort.ADDED, SortDirection.DESC)
        assertEquals("Aaa Book", vm.state.value.books.first().title)

        vm.setSort(BookSort.ADDED, SortDirection.ASC)
        assertEquals("Zzz Book", vm.state.value.books.first().title)
    }

    @Test
    fun `sorts navigation entries by title and direction`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(NAVIGATION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        // Default ascending by title.
        assertEquals("Alpha", vm.state.value.navEntries.first().title)

        vm.setSort(BookSort.TITLE, SortDirection.DESC)
        assertEquals("Zeta", vm.state.value.navEntries.first().title)
    }

    @Test
    fun `filter narrows books by title author and tag`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        vm.setFilter("zzz")
        // Matches "Zzz Book" by title and "Zzz Author" on the other book.
        assertEquals(2, vm.state.value.books.size)

        vm.setFilter("aaa author")
        assertEquals(1, vm.state.value.books.size)
        assertEquals("Zzz Book", vm.state.value.books.first().title)
    }

    @Test
    fun `clearing filter restores all entries`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        vm.setFilter("aaa book")
        assertEquals(1, vm.state.value.books.size)

        vm.setFilter("")
        assertEquals(2, vm.state.value.books.size)
    }

    @Test
    fun `sort applies to the filtered subset without losing entries`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        vm.setFilter("book")
        vm.setSort(BookSort.AUTHOR, SortDirection.ASC)
        assertEquals(2, vm.state.value.books.size)
        assertEquals("Zzz Book", vm.state.value.books.first().title)

        // Clearing the filter still yields the full, sorted set.
        vm.setFilter("")
        assertEquals(2, vm.state.value.books.size)
        assertEquals("Zzz Book", vm.state.value.books.first().title)
    }

    @Test
    fun `filter narrows navigation entries by title`() = runTest {
        server.enqueue(MockResponse().setResponseCode(200).setBody(NAVIGATION_FEED))

        val vm = viewModelForServer()
        advanceUntilIdle()

        vm.setFilter("alp")
        assertEquals(1, vm.state.value.navEntries.size)
        assertEquals("Alpha", vm.state.value.navEntries.first().title)
    }

    @Test
    fun `http error surfaces an error message`() = runTest {
        server.enqueue(MockResponse().setResponseCode(500))

        val vm = viewModelForServer()
        advanceUntilIdle()

        assertFalse(vm.state.value.loading)
        assertNotNull(vm.state.value.error)
    }

    private companion object {
        val NAVIGATION_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom">
              <title>Series</title>
              <id>urn:bookwall:series</id>
              <link rel="self" href="/opds/series" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              <entry>
                <title>Zeta</title>
                <id>urn:bookwall:series:1</id>
                <link rel="subsection" href="/opds/series/1" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              </entry>
              <entry>
                <title>Alpha</title>
                <id>urn:bookwall:series:2</id>
                <link rel="subsection" href="/opds/series/2" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              </entry>
            </feed>
        """.trimIndent()

        val ACQUISITION_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds/recent" type="application/atom+xml"/>
              <entry>
                <title>Zzz Book</title>
                <id>urn:bookwall:book:1</id>
                <author><name>Aaa Author</name></author>
                <published>2026-01-01T00:00:00Z</published>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/1/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
              <entry>
                <title>Aaa Book</title>
                <id>urn:bookwall:book:2</id>
                <author><name>Zzz Author</name></author>
                <published>2026-02-01T00:00:00Z</published>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/2/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
