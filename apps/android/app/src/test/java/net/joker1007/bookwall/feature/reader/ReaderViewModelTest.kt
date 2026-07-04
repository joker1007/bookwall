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
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.PseInfo
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.ReaderState
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.reader.ReadingQueueHolder
import net.joker1007.bookwall.data.reader.TapAction
import net.joker1007.bookwall.data.reader.TapZone
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ReaderViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val readerRepo = FakeReaderStateRepository()
    private val prefsRepo = FakeReaderPreferencesRepository()
    private val syncRepo = FakeProgressSyncRepository()
    private val queueHolder = ReadingQueueHolder()
    private val coordinator = BookOpenCoordinator()

    private fun book(id: Long, title: String) = OpdsEntry.Book(
        title = title,
        id = "urn:bookwall:book:$id",
        pse = PseInfo(streamHrefTemplate = "/opds/books/$id/pages/{pageNumber}", pageCount = 10),
    )

    private suspend fun viewModel(
        pageCount: Int = 10,
        initialPage: Int = 3,
        syncTemplate: String? = null,
        queueNext: Boolean = false,
    ): ReaderViewModel {
        val dao = FakeOpdsServerDao()
        val serverRepo = ServerRepositoryImpl(dao, FakeSecretCipher(), clock = { 0L })
        val id = serverRepo.upsert(
            OpdsServer(name = "s", baseUrl = "https://h", syncProgressTemplate = syncTemplate),
        )
        // The current book is 7; queue 8 after it so the VM resolves a next book.
        // Clear otherwise: the shared holder + reused fake server ids would leak
        // a previous test's queue into a VM that should have none.
        queueHolder.set(id, if (queueNext) listOf(book(7, "Vol 7"), book(8, "Vol 8")) else emptyList())
        val handle = SavedStateHandle(
            mapOf(
                ReaderViewModel.ARG_SERVER_ID to id,
                ReaderViewModel.ARG_BOOK_ID to 7L,
                ReaderViewModel.ARG_PAGE_COUNT to pageCount,
                ReaderViewModel.ARG_INITIAL_PAGE to initialPage,
                ReaderViewModel.ARG_TITLE to "Title",
                ReaderViewModel.ARG_PSE_TEMPLATE to "/opds/books/7/pages/{pageNumber}",
            ),
        )
        return ReaderViewModel(
            serverRepo, readerRepo, prefsRepo, { null }, syncRepo, queueHolder, coordinator,
            LocalBookSourceFactory(mainDispatcherRule.dispatcher), { error("not used off-device") },
            {}, handle,
        )
    }

    @Test
    fun `restores initial page and builds page source`() = runTest {
        val vm = viewModel(initialPage = 3)
        advanceUntilIdle()

        assertEquals(3, vm.state.value.currentPage)
        assertEquals("https://h/opds/books/7/pages/0", vm.pageSource?.pageModel(0))
        assertEquals("https://h/opds/books/7/pages/5", vm.pageSource?.pageModel(5))
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
    fun `resolves the next book from the queue`() = runTest {
        val vm = viewModel(queueNext = true)
        advanceUntilIdle()

        assertEquals("Vol 8", vm.state.value.nextBook?.title)
    }

    @Test
    fun `next book is null without a queue`() = runTest {
        val vm = viewModel(queueNext = false)
        advanceUntilIdle()

        assertTrue(vm.state.value.nextBook == null)
    }

    @Test
    fun `requestNextBookConfirm shows the dialog only when a next book exists`() = runTest {
        val withNext = viewModel(queueNext = true)
        advanceUntilIdle()
        withNext.requestNextBookConfirm()
        assertTrue(withNext.state.value.confirmNextVisible)

        val withoutNext = viewModel(queueNext = false)
        advanceUntilIdle()
        withoutNext.requestNextBookConfirm()
        assertTrue(!withoutNext.state.value.confirmNextVisible)
    }

    @Test
    fun `confirmNextBook emits an open request and dismisses`() = runTest {
        val vm = viewModel(queueNext = true)
        advanceUntilIdle()
        vm.requestNextBookConfirm()

        val request = async { coordinator.requests.first() }
        vm.confirmNextBook()

        assertEquals(8L, request.await().book.numericId)
        assertTrue(!vm.state.value.confirmNextVisible)
    }

    @Test
    fun `dismissNextBookConfirm hides the dialog`() = runTest {
        val vm = viewModel(queueNext = true)
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
}
