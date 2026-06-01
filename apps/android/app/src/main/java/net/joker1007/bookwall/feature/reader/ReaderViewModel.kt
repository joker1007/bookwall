package net.joker1007.bookwall.feature.reader

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.ImageLoader
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.reader.OpdsPageSource
import net.joker1007.bookwall.data.reader.PageSource
import net.joker1007.bookwall.data.reader.ReaderState
import net.joker1007.bookwall.data.reader.ReaderStateRepository
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.ServerImageLoaderProvider
import javax.inject.Inject

data class ReaderUiState(
    val title: String = "",
    val loading: Boolean = true,
    val error: String? = null,
    val pageCount: Int = 0,
    val currentPage: Int = 0,
    val direction: ReadingDirection = ReadingDirection.RTL,
    val spreadEnabled: Boolean = false,
    val menuVisible: Boolean = false,
)

@HiltViewModel
class ReaderViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val readerStateRepository: ReaderStateRepository,
    private val imageLoaderProvider: ServerImageLoaderProvider,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val serverId: Long = savedStateHandle.get<Long>(ARG_SERVER_ID) ?: 0L
    private val bookId: Long = savedStateHandle.get<Long>(ARG_BOOK_ID) ?: 0L
    private val pageCount: Int = savedStateHandle.get<Int>(ARG_PAGE_COUNT) ?: 0
    private val initialPage: Int = savedStateHandle.get<Int>(ARG_INITIAL_PAGE) ?: 0
    private val title: String = savedStateHandle.get<String>(ARG_TITLE).orEmpty()
    private val pseTemplate: String = savedStateHandle.get<String>(ARG_PSE_TEMPLATE).orEmpty()

    private val _state = MutableStateFlow(ReaderUiState(title = title, pageCount = pageCount))
    val state: StateFlow<ReaderUiState> = _state.asStateFlow()

    private val _imageLoader = MutableStateFlow<ImageLoader?>(null)
    val imageLoader: StateFlow<ImageLoader?> = _imageLoader.asStateFlow()

    var pageSource: PageSource? = null
        private set

    init {
        load()
    }

    private fun load() {
        viewModelScope.launch {
            val server = serverRepository.getServer(serverId)
            if (server == null) {
                _state.update { it.copy(loading = false, error = "サーバーが見つかりません") }
                return@launch
            }
            _imageLoader.value = imageLoaderProvider.forServer(server)
            pageSource = OpdsPageSource(server.baseUrl, pseTemplate, pageCount)

            val saved = readerStateRepository.load(serverId, bookId)
            _state.update {
                it.copy(
                    loading = false,
                    currentPage = clampPage(saved?.currentPage ?: initialPage),
                    direction = saved?.direction ?: it.direction,
                    spreadEnabled = saved?.spreadEnabled ?: it.spreadEnabled,
                )
            }
        }
    }

    fun next() = goToPage(_state.value.currentPage + 1)

    fun previous() = goToPage(_state.value.currentPage - 1)

    fun goToPage(page: Int) {
        val target = clampPage(page)
        if (target == _state.value.currentPage) return
        _state.update { it.copy(currentPage = target) }
        persist()
    }

    /** Reports the page the pager settled on (from a swipe). */
    fun onPageSettled(page: Int) = goToPage(page)

    fun toggleMenu() = _state.update { it.copy(menuVisible = !it.menuVisible) }

    fun setDirection(direction: ReadingDirection) {
        if (direction == _state.value.direction) return
        _state.update { it.copy(direction = direction) }
        persist()
    }

    private fun clampPage(page: Int): Int = page.coerceIn(0, (pageCount - 1).coerceAtLeast(0))

    private fun persist() {
        val s = _state.value
        viewModelScope.launch {
            readerStateRepository.save(
                serverId, bookId,
                ReaderState(currentPage = s.currentPage, direction = s.direction, spreadEnabled = s.spreadEnabled),
            )
        }
    }

    companion object {
        const val ARG_SERVER_ID = "serverId"
        const val ARG_BOOK_ID = "bookId"
        const val ARG_PAGE_COUNT = "pageCount"
        const val ARG_INITIAL_PAGE = "initialPage"
        const val ARG_TITLE = "title"
        const val ARG_PSE_TEMPLATE = "pseTemplate"
    }
}
