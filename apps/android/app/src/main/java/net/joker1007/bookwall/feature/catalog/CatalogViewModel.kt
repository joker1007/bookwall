package net.joker1007.bookwall.feature.catalog

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
import net.joker1007.bookwall.data.epub.EpubOpener
import net.joker1007.bookwall.data.epub.EpubProgressRepository
import net.joker1007.bookwall.data.epub.EpubReaderHolder
import net.joker1007.bookwall.data.opds.FeedResult
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.OpdsFeed
import net.joker1007.bookwall.data.opds.OpdsRepository
import net.joker1007.bookwall.data.opds.isEpub
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.opds.resolveOpdsHref
import net.joker1007.bookwall.data.reader.ReaderStateRepository
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.ServerImageLoaderProvider
import javax.inject.Inject

enum class ViewMode { GRID, LIST }

enum class BookSort { TITLE, AUTHOR }

data class CatalogUiState(
    val title: String = "",
    val loading: Boolean = true,
    val error: String? = null,
    val navEntries: List<OpdsEntry.Navigation> = emptyList(),
    val books: List<OpdsEntry.Book> = emptyList(),
    val viewMode: ViewMode = ViewMode.GRID,
    val sort: BookSort = BookSort.TITLE,
    val openingEpub: Boolean = false,
)

@HiltViewModel
class CatalogViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val opdsRepository: OpdsRepository,
    private val imageLoaderFactory: ServerImageLoaderProvider,
    private val epubOpener: EpubOpener,
    private val epubHolder: EpubReaderHolder,
    private val readerStateRepository: ReaderStateRepository,
    private val epubProgressRepository: EpubProgressRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val serverId: Long = savedStateHandle.get<Long>(ARG_SERVER_ID) ?: 0L
    private val feedUrlArg: String? = savedStateHandle.get<String>(ARG_FEED_URL)?.ifEmpty { null }

    private val _state = MutableStateFlow(CatalogUiState())
    val state: StateFlow<CatalogUiState> = _state.asStateFlow()

    private val _selectedBook = MutableStateFlow<OpdsEntry.Book?>(null)
    val selectedBook: StateFlow<OpdsEntry.Book?> = _selectedBook.asStateFlow()

    /** Local reading position (0-based) for the selected image book, or null. */
    private val _selectedLocalPage = MutableStateFlow<Int?>(null)
    val selectedLocalPage: StateFlow<Int?> = _selectedLocalPage.asStateFlow()

    /** Local reading progression (0..1) for the selected EPUB, or null. */
    private val _selectedEpubProgress = MutableStateFlow<Float?>(null)
    val selectedEpubProgress: StateFlow<Float?> = _selectedEpubProgress.asStateFlow()

    private val _epubSessionId = MutableStateFlow<Long?>(null)
    val epubSessionId: StateFlow<Long?> = _epubSessionId.asStateFlow()

    private val _imageLoader = MutableStateFlow<ImageLoader?>(null)
    val imageLoader: StateFlow<ImageLoader?> = _imageLoader.asStateFlow()

    private var server: OpdsServer? = null

    init {
        load()
    }

    fun retry() = load()

    fun setViewMode(mode: ViewMode) = _state.update { it.copy(viewMode = mode) }

    fun setSort(sort: BookSort) =
        _state.update { it.copy(sort = sort, books = sortBooks(it.books, sort)) }

    fun selectBook(book: OpdsEntry.Book) {
        _selectedBook.value = book
        _selectedLocalPage.value = null
        _selectedEpubProgress.value = null
        val bookId = book.numericId ?: return
        viewModelScope.launch {
            if (book.isEpub) {
                _selectedEpubProgress.value = epubProgressRepository.load(serverId, bookId)
                    ?.locations?.totalProgression?.toFloat()
            } else {
                _selectedLocalPage.value = readerStateRepository.load(serverId, bookId)?.currentPage
            }
        }
    }

    fun dismissBook() {
        _selectedBook.value = null
        _selectedLocalPage.value = null
        _selectedEpubProgress.value = null
    }

    fun openEpub(book: OpdsEntry.Book) {
        val srv = server ?: return
        _state.update { it.copy(openingEpub = true) }
        viewModelScope.launch {
            epubOpener.open(srv, book)
                .onSuccess { session -> _epubSessionId.value = epubHolder.put(session) }
            _state.update { it.copy(openingEpub = false) }
        }
    }

    fun consumeEpubLaunch() {
        _epubSessionId.value = null
    }

    /** Resolves an OPDS href (relative or absolute) against the active server. */
    fun resolve(href: String?): String? {
        val base = server?.baseUrl ?: return null
        return href?.let { resolveOpdsHref(base, it) }
    }

    private fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val srv = serverRepository.getServer(serverId)
            if (srv == null) {
                _state.update { it.copy(loading = false, error = "サーバーが見つかりません") }
                return@launch
            }
            server = srv
            _imageLoader.value = imageLoaderFactory.forServer(srv)

            when (val result = opdsRepository.fetchFeed(srv, feedUrlArg ?: srv.baseUrl)) {
                is FeedResult.Success -> _state.update { it.applyFeed(result.feed) }
                FeedResult.AuthFailed -> fail("認証に失敗しました (401)")
                is FeedResult.HttpError -> fail("サーバーエラー (${result.code})")
                FeedResult.InvalidUrl -> fail("URL が不正です")
                FeedResult.ParseError -> fail("フィードを解析できませんでした")
                is FeedResult.NetworkError -> fail("接続できません: ${result.message ?: "ネットワークエラー"}")
            }
        }
    }

    private fun fail(message: String) = _state.update { it.copy(loading = false, error = message) }

    private fun CatalogUiState.applyFeed(feed: OpdsFeed): CatalogUiState = copy(
        loading = false,
        error = null,
        title = feed.title,
        navEntries = feed.entries.filterIsInstance<OpdsEntry.Navigation>(),
        books = sortBooks(feed.entries.filterIsInstance<OpdsEntry.Book>(), sort),
    )

    private fun sortBooks(books: List<OpdsEntry.Book>, sort: BookSort): List<OpdsEntry.Book> =
        when (sort) {
            BookSort.TITLE -> books.sortedBy { it.title.lowercase() }
            BookSort.AUTHOR -> books.sortedBy { it.authors.firstOrNull()?.lowercase() ?: "￿" }
        }

    companion object {
        const val ARG_SERVER_ID = "serverId"
        const val ARG_FEED_URL = "feedUrl"
    }
}
