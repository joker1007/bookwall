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
import net.joker1007.bookwall.data.epub.EpubDownloader
import net.joker1007.bookwall.data.epub.EpubProgressRepository
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
import java.time.OffsetDateTime
import javax.inject.Inject

enum class ViewMode { GRID, LIST }

enum class BookSort { TITLE, AUTHOR, ADDED }

enum class SortDirection { ASC, DESC }

/** A downloaded EPUB ready to hand to the foliate-js reader activity. */
data class FoliateLaunch(
    val serverId: Long,
    val bookId: Long,
    val title: String,
    val filePath: String,
)

data class CatalogUiState(
    val title: String = "",
    val loading: Boolean = true,
    val error: String? = null,
    val navEntries: List<OpdsEntry.Navigation> = emptyList(),
    val books: List<OpdsEntry.Book> = emptyList(),
    val viewMode: ViewMode = ViewMode.GRID,
    val sort: BookSort = BookSort.TITLE,
    val sortDirection: SortDirection = SortDirection.ASC,
    val filterQuery: String = "",
    val openingEpub: Boolean = false,
)

@HiltViewModel
class CatalogViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val opdsRepository: OpdsRepository,
    private val imageLoaderFactory: ServerImageLoaderProvider,
    private val epubDownloader: EpubDownloader,
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

    private val _foliateLaunch = MutableStateFlow<FoliateLaunch?>(null)
    val foliateLaunch: StateFlow<FoliateLaunch?> = _foliateLaunch.asStateFlow()

    private val _imageLoader = MutableStateFlow<ImageLoader?>(null)
    val imageLoader: StateFlow<ImageLoader?> = _imageLoader.asStateFlow()

    private var server: OpdsServer? = null

    // Full, unfiltered entries from the current feed; the displayed lists in
    // CatalogUiState are derived from these by applying sort + filter.
    private var sourceNav: List<OpdsEntry.Navigation> = emptyList()
    private var sourceBooks: List<OpdsEntry.Book> = emptyList()

    init {
        load()
    }

    fun retry() = load()

    fun setViewMode(mode: ViewMode) = _state.update { it.copy(viewMode = mode) }

    fun setSort(sort: BookSort, direction: SortDirection) =
        _state.update { it.copy(sort = sort, sortDirection = direction).recompute() }

    fun setFilter(query: String) =
        _state.update { it.copy(filterQuery = query).recompute() }

    fun selectBook(book: OpdsEntry.Book) {
        _selectedBook.value = book
        _selectedLocalPage.value = null
        _selectedEpubProgress.value = null
        val bookId = book.numericId ?: return
        viewModelScope.launch {
            if (book.isEpub) {
                _selectedEpubProgress.value = epubProgressRepository.load(serverId, bookId)?.fraction
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
        val bookId = book.numericId ?: return
        _state.update { it.copy(openingEpub = true) }
        viewModelScope.launch {
            runCatching { epubDownloader.download(srv, book) }
                .onSuccess { file ->
                    _foliateLaunch.value = FoliateLaunch(
                        serverId = srv.id,
                        bookId = bookId,
                        title = book.title,
                        filePath = file.absolutePath,
                    )
                }
            _state.update { it.copy(openingEpub = false) }
        }
    }

    fun consumeFoliateLaunch() {
        _foliateLaunch.value = null
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
                is FeedResult.Success -> {
                    // The progress-sync capability is advertised only on the root feed,
                    // so re-evaluate it whenever we load a server's entry point.
                    if (feedUrlArg == null) {
                        serverRepository.setSyncProgressTemplate(serverId, result.feed.progressSyncTemplate)
                        server = srv.copy(syncProgressTemplate = result.feed.progressSyncTemplate)
                    }
                    _state.update { it.applyFeed(result.feed) }
                }
                FeedResult.AuthFailed -> fail("認証に失敗しました (401)")
                is FeedResult.HttpError -> fail("サーバーエラー (${result.code})")
                FeedResult.InvalidUrl -> fail("URL が不正です")
                FeedResult.ParseError -> fail("フィードを解析できませんでした")
                is FeedResult.NetworkError -> fail("接続できません: ${result.message ?: "ネットワークエラー"}")
            }
        }
    }

    private fun fail(message: String) = _state.update { it.copy(loading = false, error = message) }

    private fun CatalogUiState.applyFeed(feed: OpdsFeed): CatalogUiState {
        sourceNav = feed.entries.filterIsInstance<OpdsEntry.Navigation>()
        sourceBooks = feed.entries.filterIsInstance<OpdsEntry.Book>()
        return copy(loading = false, error = null, title = feed.title).recompute()
    }

    // Derive the displayed lists from the full source entries using the current
    // sort and filter. Sort first, then filter, so order is stable as the query changes.
    private fun CatalogUiState.recompute(): CatalogUiState {
        val nav = sortNav(sourceNav, sortDirection).filter { it.matchesFilter(filterQuery) }
        val books = sortBooks(sourceBooks, sort, sortDirection).filter { it.matchesFilter(filterQuery) }
        return copy(navEntries = nav, books = books)
    }

    private fun OpdsEntry.Navigation.matchesFilter(query: String): Boolean {
        val q = query.trim()
        if (q.isEmpty()) return true
        return title.contains(q, ignoreCase = true) || summary?.contains(q, ignoreCase = true) == true
    }

    private fun OpdsEntry.Book.matchesFilter(query: String): Boolean {
        val q = query.trim()
        if (q.isEmpty()) return true
        return title.contains(q, ignoreCase = true) ||
            authors.any { it.contains(q, ignoreCase = true) } ||
            tags.any { it.contains(q, ignoreCase = true) }
    }

    // Navigation entries only have a title axis; honour the chosen direction.
    private fun sortNav(
        entries: List<OpdsEntry.Navigation>,
        direction: SortDirection,
    ): List<OpdsEntry.Navigation> {
        val sorted = entries.sortedBy { it.title.lowercase() }
        return if (direction == SortDirection.DESC) sorted.asReversed() else sorted
    }

    private fun sortBooks(
        books: List<OpdsEntry.Book>,
        sort: BookSort,
        direction: SortDirection,
    ): List<OpdsEntry.Book> {
        val sorted = when (sort) {
            // Sentinel "￿" pushes entries with no title/author to the end (ascending).
            BookSort.TITLE -> books.sortedBy { it.title.lowercase() }
            BookSort.AUTHOR -> books.sortedBy { it.authors.firstOrNull()?.lowercase() ?: "￿" }
            BookSort.ADDED -> books.sortedBy { addedEpoch(it) }
        }
        return if (direction == SortDirection.DESC) sorted.asReversed() else sorted
    }

    // Unknown/unparseable dates sort oldest (ascending) so they sit out of the way.
    private fun addedEpoch(book: OpdsEntry.Book): Long =
        book.added?.let {
            runCatching { OffsetDateTime.parse(it).toInstant().toEpochMilli() }.getOrNull()
        } ?: Long.MIN_VALUE

    companion object {
        const val ARG_SERVER_ID = "serverId"
        const val ARG_FEED_URL = "feedUrl"
    }
}
