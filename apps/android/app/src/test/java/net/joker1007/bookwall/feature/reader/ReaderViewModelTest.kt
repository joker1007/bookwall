package net.joker1007.bookwall.feature.reader

import androidx.lifecycle.SavedStateHandle
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.MainDispatcherRule
import net.joker1007.bookwall.data.FakeOpdsServerDao
import net.joker1007.bookwall.data.reader.local.LocalBookSourceFactory
import net.joker1007.bookwall.data.FakeProgressSyncRepository
import net.joker1007.bookwall.data.FakeReaderPreferencesRepository
import net.joker1007.bookwall.data.FakeReaderStateRepository
import net.joker1007.bookwall.data.FakeSecretCipher
import net.joker1007.bookwall.data.opds.FeedParser
import net.joker1007.bookwall.data.opds.OpdsFeed
import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.opds.OpdsRepository
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.NextInSeriesResolver
import net.joker1007.bookwall.data.reader.ReaderState
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.reader.TapAction
import net.joker1007.bookwall.data.reader.TapZone
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.kxml2.io.KXmlParser
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream

@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val readerRepo = FakeReaderStateRepository()
    private val prefsRepo = FakeReaderPreferencesRepository()
    private val syncRepo = FakeProgressSyncRepository()
    private val coordinator = BookOpenCoordinator()

    private lateinit var mockServer: MockWebServer

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
        mockServer = MockWebServer().apply { start() }
    }

    @After
    fun tearDown() {
        mockServer.shutdown()
    }

    private suspend fun viewModel(
        pageCount: Int = 10,
        initialPage: Int = 3,
        syncTemplate: String? = null,
        seriesNext: Boolean = false,
    ): ReaderViewModel {
        val dao = FakeOpdsServerDao()
        val serverRepo = ServerRepositoryImpl(dao, FakeSecretCipher(), clock = { 0L })
        val baseUrl = mockServer.url("/opds").toString()
        val id = serverRepo.upsert(
            OpdsServer(name = "s", baseUrl = baseUrl, syncProgressTemplate = syncTemplate),
        )
        // The current book is 7; when seriesNext the series feed lists 7 then 8,
        // so the resolver picks 8 as the next volume.
        if (seriesNext) mockServer.enqueue(MockResponse().setResponseCode(200).setBody(SERIES_FEED))
        val opdsRepo = OpdsRepository(OkHttpClientFactory(OkHttpClient()), feedParser, mainDispatcherRule.dispatcher)
        val resolver = NextInSeriesResolver(opdsRepo)
        val handle = SavedStateHandle(
            mapOf(
                ReaderViewModel.ARG_SERVER_ID to id,
                ReaderViewModel.ARG_BOOK_ID to 7L,
                ReaderViewModel.ARG_PAGE_COUNT to pageCount,
                ReaderViewModel.ARG_INITIAL_PAGE to initialPage,
                ReaderViewModel.ARG_TITLE to "Title",
                ReaderViewModel.ARG_PSE_TEMPLATE to "/opds/books/7/pages/{pageNumber}",
                ReaderViewModel.ARG_SERIES_HREF to if (seriesNext) "/opds/series/1" else "",
            ),
        )
        return ReaderViewModel(
            serverRepo, readerRepo, prefsRepo, { null }, syncRepo, resolver, coordinator,
            LocalBookSourceFactory(mainDispatcherRule.dispatcher), { error("not used off-device") },
            {}, handle,
        )
    }

    @Test
    fun `restores initial page and builds page source`() = runTest {
        val vm = viewModel(initialPage = 3)
        advanceUntilIdle()

        val base = mockServer.url("").toString().trimEnd('/')
        assertEquals(3, vm.state.value.currentPage)
        assertEquals("$base/opds/books/7/pages/0", vm.pageSource?.pageModel(0))
        assertEquals("$base/opds/books/7/pages/5", vm.pageSource?.pageModel(5))
    }

    @Test
    fun `saved state overrides the initial page`() = runTest {
        readerRepo.preset = ReaderState(currentPage = 5, direction = ReadingDirection.LTR)
        val vm = viewModel(initialPage = 3)
        advanceUntilIdle()

        assertEquals(5, vm.state.value.currentPage)
        assertEquals(ReadingDirection.LTR, vm.state.value.direction)
    }

    @Test
    fun `next and previous advance and clamp within bounds`() = runTest {
        val vm = viewModel(pageCount = 10, initialPage = 0)
        advanceUntilIdle()

        vm.previous()
        assertEquals(0, vm.state.value.currentPage)

        vm.next()
        assertEquals(1, vm.state.value.currentPage)

        vm.goToPage(100)
        assertEquals(9, vm.state.value.currentPage)
    }

    @Test
    fun `navigation persists progress`() = runTest {
        val vm = viewModel(initialPage = 0)
        advanceUntilIdle()

        vm.next()
        advanceUntilIdle()

        val stored = readerRepo.saved[0L to 7L] ?: readerRepo.saved.values.firstOrNull()
        assertNotNull(stored)
        assertEquals(1, stored!!.currentPage)
    }

    @Test
    fun `toggleMenu flips visibility`() = runTest {
        val vm = viewModel()
        advanceUntilIdle()

        assertTrue(!vm.state.value.menuVisible)
        vm.toggleMenu()
        assertTrue(vm.state.value.menuVisible)
    }

    @Test
    fun `setSpread updates and persists`() = runTest {
        val vm = viewModel(initialPage = 0)
        advanceUntilIdle()

        vm.setSpread(true)
        advanceUntilIdle()

        assertTrue(vm.state.value.spreadEnabled)
        assertTrue(readerRepo.saved.values.first().spreadEnabled)
    }

    @Test
    fun `nudgeOffset toggles between 0 and 1`() = runTest {
        val vm = viewModel()
        advanceUntilIdle()

        assertEquals(0, vm.state.value.pageOffset)
        vm.nudgeOffset()
        assertEquals(1, vm.state.value.pageOffset)
        vm.nudgeOffset()
        assertEquals(0, vm.state.value.pageOffset)
    }

    @Test
    fun `pushes progress to a sync-capable server on navigation`() = runTest {
        val vm = viewModel(initialPage = 0, syncTemplate = "/opds/books/{bookId}/progress")
        advanceUntilIdle()

        vm.next()
        advanceUntilIdle()

        assertEquals(1, syncRepo.pushes.size)
        assertEquals(1, syncRepo.pushes.last().page)
        assertEquals(7L, syncRepo.pushes.last().bookId)
    }

    @Test
    fun `does not push when the server lacks sync support`() = runTest {
        val vm = viewModel(initialPage = 0, syncTemplate = null)
        advanceUntilIdle()

        vm.next()
        advanceUntilIdle()

        assertTrue(syncRepo.pushes.isEmpty())
    }

    @Test
    fun `resolves the next volume from the series feed`() = runTest {
        val vm = viewModel(seriesNext = true)
        advanceUntilIdle()

        assertEquals("Vol 8", vm.state.value.nextBook?.title)
    }

    @Test
    fun `next book is null without a series`() = runTest {
        val vm = viewModel(seriesNext = false)
        advanceUntilIdle()

        assertTrue(vm.state.value.nextBook == null)
    }

    @Test
    fun `requestNextBookConfirm shows the dialog only when a next book exists`() = runTest {
        val withNext = viewModel(seriesNext = true)
        advanceUntilIdle()
        withNext.requestNextBookConfirm()
        assertTrue(withNext.state.value.confirmNextVisible)

        val withoutNext = viewModel(seriesNext = false)
        advanceUntilIdle()
        withoutNext.requestNextBookConfirm()
        assertTrue(!withoutNext.state.value.confirmNextVisible)
    }

    @Test
    fun `confirmNextBook emits an open request and dismisses`() = runTest {
        val vm = viewModel(seriesNext = true)
        advanceUntilIdle()
        vm.requestNextBookConfirm()

        val request = async { coordinator.requests.first() }
        vm.confirmNextBook()

        assertEquals(8L, request.await().book.numericId)
        assertTrue(!vm.state.value.confirmNextVisible)
    }

    @Test
    fun `dismissNextBookConfirm hides the dialog`() = runTest {
        val vm = viewModel(seriesNext = true)
        advanceUntilIdle()
        vm.requestNextBookConfirm()
        vm.dismissNextBookConfirm()

        assertTrue(!vm.state.value.confirmNextVisible)
    }

    @Test
    fun `setZoneAction persists to preferences`() = runTest {
        val vm = viewModel()
        advanceUntilIdle()

        vm.setZoneAction(TapZone.LEFT, TapAction.NEXT_CONTINUOUS)
        advanceUntilIdle()

        assertEquals(TapAction.NEXT_CONTINUOUS, prefsRepo.current().left)
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
