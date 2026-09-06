package net.joker1007.bookwall.feature.reader

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.ImageLoader
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.OpdsPageSource
import net.joker1007.bookwall.data.reader.PageSource
import net.joker1007.bookwall.data.reader.local.ClosablePageSource
import net.joker1007.bookwall.data.reader.local.LocalBook
import net.joker1007.bookwall.data.reader.local.LocalBookSourceFactory
import net.joker1007.bookwall.data.reader.local.LocalImageLoaderProvider
import net.joker1007.bookwall.data.reader.ProgressSyncRepository
import net.joker1007.bookwall.data.reader.ProgressSyncScheduler
import net.joker1007.bookwall.data.reader.ReaderPreferencesRepository
import net.joker1007.bookwall.data.reader.ReaderState
import net.joker1007.bookwall.data.reader.NextInSeriesResolver
import net.joker1007.bookwall.data.reader.ReaderStateRepository
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.reader.SpreadMode
import net.joker1007.bookwall.data.reader.TapAction
import net.joker1007.bookwall.data.reader.TapZone
import net.joker1007.bookwall.data.reader.TapZoneConfig
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.ServerImageLoaderProvider
import java.io.File
import javax.inject.Inject

data class ReaderUiState(
    val title: String = "",
    val loading: Boolean = true,
    val error: String? = null,
    val pageCount: Int = 0,
    val currentPage: Int = 0,
    val direction: ReadingDirection = ReadingDirection.RTL,
    val spreadMode: SpreadMode = SpreadMode.OFF,
    /** Shifts spread pairing by one page to realign mismatched spreads (0 or 1). */
    val pageOffset: Int = 0,
    val menuVisible: Boolean = false,
    val settingsVisible: Boolean = false,
    /** Next volume in the same series, or null when there is none. */
    val nextBook: OpdsEntry.Book? = null,
    /** Whether the "open the next book?" confirmation dialog is shown. */
    val confirmNextVisible: Boolean = false,
)

@HiltViewModel
class ReaderViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val readerStateRepository: ReaderStateRepository,
    private val preferencesRepository: ReaderPreferencesRepository,
    private val imageLoaderProvider: ServerImageLoaderProvider,
    private val progressSyncRepository: ProgressSyncRepository,
    private val nextInSeriesResolver: NextInSeriesResolver,
    private val bookOpenCoordinator: BookOpenCoordinator,
    private val localBookSourceFactory: LocalBookSourceFactory,
    private val localImageLoaderProvider: LocalImageLoaderProvider,
    private val progressSyncScheduler: ProgressSyncScheduler,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val serverId: Long = savedStateHandle.get<Long>(ARG_SERVER_ID) ?: 0L
    private val bookId: Long = savedStateHandle.get<Long>(ARG_BOOK_ID) ?: 0L
    private var pageCount: Int = savedStateHandle.get<Int>(ARG_PAGE_COUNT) ?: 0
    private val initialPage: Int = savedStateHandle.get<Int>(ARG_INITIAL_PAGE) ?: 0
    private val title: String = savedStateHandle.get<String>(ARG_TITLE).orEmpty()
    private val pseTemplate: String = savedStateHandle.get<String>(ARG_PSE_TEMPLATE).orEmpty()
    private val localPath: String = savedStateHandle.get<String>(ARG_LOCAL_PATH).orEmpty()
    private val seriesHref: String = savedStateHandle.get<String>(ARG_SERIES_HREF).orEmpty()

    private val _state = MutableStateFlow(ReaderUiState(title = title, pageCount = pageCount))
    val state: StateFlow<ReaderUiState> = _state.asStateFlow()

    private val _imageLoader = MutableStateFlow<ImageLoader?>(null)
    val imageLoader: StateFlow<ImageLoader?> = _imageLoader.asStateFlow()

    val tapZoneConfig: StateFlow<TapZoneConfig> = preferencesRepository.tapZoneConfig
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TapZoneConfig())

    var pageSource: PageSource? = null
        private set

    private var server: OpdsServer? = null
    private var syncJob: Job? = null

    init {
        load()
    }

    private fun load() {
        viewModelScope.launch {
            // The server is optional for local files; it is only used for streaming
            // pages and pushing progress (both skipped when it is unavailable).
            val srv = serverRepository.getServer(serverId)
            server = srv
            if (localPath.isNotEmpty()) {
                if (!openLocalBook()) return@launch
            } else {
                if (srv == null) {
                    _state.update { it.copy(loading = false, error = "サーバーが見つかりません") }
                    return@launch
                }
                _imageLoader.value = imageLoaderProvider.forServer(srv)
                pageSource = OpdsPageSource(srv.baseUrl, pseTemplate, pageCount)
            }

            val saved = readerStateRepository.load(serverId, bookId)
            _state.update {
                it.copy(
                    loading = false,
                    pageCount = pageCount,
                    currentPage = clampPage(saved?.currentPage ?: initialPage),
                    direction = saved?.direction ?: it.direction,
                    spreadMode = saved?.spreadMode ?: it.spreadMode,
                )
            }
            // Resolve the next volume off the critical path: it needs a network
            // fetch of the series feed and only gates the end-of-book roll-over.
            if (srv != null && seriesHref.isNotEmpty()) {
                launch {
                    nextInSeriesResolver.resolve(srv, seriesHref, bookId)?.let { next ->
                        _state.update { it.copy(nextBook = next) }
                    }
                }
            }
        }
    }

    private suspend fun openLocalBook(): Boolean {
        val opened = runCatching { localBookSourceFactory.open(File(localPath)) }.getOrNull()
        val images = opened as? LocalBook.Images
        if (images == null) {
            _state.update { it.copy(loading = false, error = "ファイルを開けませんでした") }
            return false
        }
        pageSource = images.pageSource
        // The archive itself is authoritative (nav args may carry a stale count).
        pageCount = images.pageSource.pageCount
        _imageLoader.value = localImageLoaderProvider.localImageLoader()
        return true
    }

    override fun onCleared() {
        (pageSource as? ClosablePageSource)?.close()
    }

    /** Tapping forward past the last page: ask whether to roll over to the next book. */
    fun requestNextBookConfirm() {
        if (_state.value.nextBook == null) return
        _state.update { it.copy(confirmNextVisible = true) }
    }

    fun dismissNextBookConfirm() = _state.update { it.copy(confirmNextVisible = false) }

    fun confirmNextBook() {
        val next = _state.value.nextBook ?: return
        _state.update { it.copy(confirmNextVisible = false) }
        bookOpenCoordinator.request(serverId, next)
    }

    fun next() = goToPage(_state.value.currentPage + 1)

    fun previous() = goToPage(_state.value.currentPage - 1)

    fun goToPage(page: Int) {
        val target = clampPage(page)
        if (target == _state.value.currentPage) return
        _state.update { it.copy(currentPage = target) }
        persist()
        scheduleSync(target)
    }

    /** Reports the page the pager settled on (from a swipe). */
    fun onPageSettled(page: Int) = goToPage(page)

    fun toggleMenu() = _state.update { it.copy(menuVisible = !it.menuVisible) }

    fun openSettings() = _state.update { it.copy(settingsVisible = true) }

    fun closeSettings() = _state.update { it.copy(settingsVisible = false) }

    fun setDirection(direction: ReadingDirection) {
        if (direction == _state.value.direction) return
        _state.update { it.copy(direction = direction) }
        persist()
    }

    fun setSpreadMode(mode: SpreadMode) {
        if (mode == _state.value.spreadMode) return
        _state.update { it.copy(spreadMode = mode) }
        persist()
    }

    /** Shifts spread pairing by one page (transient; not persisted). */
    fun nudgeOffset() = _state.update { it.copy(pageOffset = (it.pageOffset + 1) % 2) }

    fun setZoneAction(zone: TapZone, action: TapAction) {
        viewModelScope.launch { preferencesRepository.setZoneAction(zone, action) }
    }

    /**
     * Debounced push of the current page to the server. Rapid page flips cancel
     * the pending push; only Bookwall servers (supportsProgressSync) actually
     * hit the network. A failed push (e.g. reading a cached book offline) leaves
     * the row dirty and hands retry to the background sync worker.
     */
    private fun scheduleSync(page: Int) {
        val srv = server ?: return
        if (!srv.supportsProgressSync) return
        syncJob?.cancel()
        syncJob = viewModelScope.launch {
            delay(SYNC_DEBOUNCE_MS)
            if (progressSyncRepository.pushPageProgress(srv, bookId, page, pageCount)) {
                readerStateRepository.markSynced(serverId, bookId)
            } else {
                progressSyncScheduler.schedule()
            }
        }
    }

    private fun clampPage(page: Int): Int = page.coerceIn(0, (pageCount - 1).coerceAtLeast(0))

    private fun persist() {
        val s = _state.value
        viewModelScope.launch {
            readerStateRepository.save(
                serverId, bookId,
                ReaderState(currentPage = s.currentPage, direction = s.direction, spreadMode = s.spreadMode),
            )
        }
    }

    companion object {
        private const val SYNC_DEBOUNCE_MS = 2_000L

        const val ARG_SERVER_ID = "serverId"
        const val ARG_BOOK_ID = "bookId"
        const val ARG_PAGE_COUNT = "pageCount"
        const val ARG_INITIAL_PAGE = "initialPage"
        const val ARG_TITLE = "title"
        const val ARG_PSE_TEMPLATE = "pseTemplate"
        const val ARG_LOCAL_PATH = "localPath"
        const val ARG_SERIES_HREF = "seriesHref"
    }
}
