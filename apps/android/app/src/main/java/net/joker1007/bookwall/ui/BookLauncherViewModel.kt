package net.joker1007.bookwall.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.cache.CacheSettingsRepository
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.epub.EpubDownloader
import net.joker1007.bookwall.data.opds.EPUB_MIME
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.isEpub
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.OpenBookRequest
import net.joker1007.bookwall.feature.catalog.FoliateLaunch
import net.joker1007.bookwall.data.server.ServerRepository
import javax.inject.Inject

/**
 * App-scoped launcher that owns the "how do we open this book?" branching:
 * cached local file vs. PSE streaming vs. EPUB download, for both catalog taps
 * and reader roll-over. [BookwallApp] observes [readerRoute] / [foliateLaunch]
 * and performs the navigation / activity start.
 */
@HiltViewModel
class BookLauncherViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val epubDownloader: EpubDownloader,
    private val bookCacheRepository: BookCacheRepository,
    private val cacheSettingsRepository: CacheSettingsRepository,
    coordinator: BookOpenCoordinator,
) : ViewModel() {

    /** Roll-over requests raised by a reader reaching the end of a book. */
    val openRequests: Flow<OpenBookRequest> = coordinator.requests

    private val _foliateLaunch = MutableStateFlow<FoliateLaunch?>(null)
    val foliateLaunch: StateFlow<FoliateLaunch?> = _foliateLaunch.asStateFlow()

    /** Image-reader route to navigate to, or null. */
    private val _readerRoute = MutableStateFlow<String?>(null)
    val readerRoute: StateFlow<String?> = _readerRoute.asStateFlow()

    /** Opens [book], preferring the local cache over the network. */
    fun open(serverId: Long, book: OpdsEntry.Book) {
        viewModelScope.launch {
            val bookId = book.numericId
            val cached = bookId?.let { bookCacheRepository.cachedFile(serverId, it) }
            val autoCache = cached == null && cacheSettingsRepository.settings.first().autoCacheOnRead
            when {
                book.isEpub -> {
                    if (cached != null) {
                        _foliateLaunch.value =
                            FoliateLaunch(serverId, bookId, book.title, cached.absolutePath, book.seriesHref)
                    } else {
                        downloadAndOpenEpub(serverId, book, adoptAsCache = autoCache)
                    }
                }
                book.pse != null || cached != null -> {
                    if (autoCache && book.pse != null) {
                        // Read via streaming now; the file downloads in the background.
                        serverRepository.getServer(serverId)?.let { bookCacheRepository.enqueue(it, book) }
                    }
                    _readerRoute.value = Destinations.reader(serverId, book, cached?.absolutePath)
                }
            }
        }
    }

    /** Opens a cached book from the downloads screen (feed metadata unavailable). */
    fun openCached(entity: CachedBookEntity) {
        viewModelScope.launch {
            val file = bookCacheRepository.cachedFile(entity.serverId, entity.bookId) ?: return@launch
            if (entity.format == EPUB_MIME) {
                _foliateLaunch.value =
                    FoliateLaunch(entity.serverId, entity.bookId, entity.title, file.absolutePath)
            } else {
                _readerRoute.value = Destinations.cachedReader(
                    serverId = entity.serverId,
                    bookId = entity.bookId,
                    pageCount = entity.pageCount,
                    title = entity.title,
                    localPath = file.absolutePath,
                )
            }
        }
    }

    private suspend fun downloadAndOpenEpub(serverId: Long, book: OpdsEntry.Book, adoptAsCache: Boolean) {
        val bookId = book.numericId ?: return
        val srv = serverRepository.getServer(serverId) ?: return
        runCatching { epubDownloader.download(srv, book) }
            .onSuccess { file ->
                // Auto-cache: register the file just downloaded instead of fetching twice.
                if (adoptAsCache) bookCacheRepository.adoptFile(srv, book, file)
                _foliateLaunch.value = FoliateLaunch(
                    serverId = srv.id,
                    bookId = bookId,
                    title = book.title,
                    filePath = file.absolutePath,
                    seriesHref = book.seriesHref,
                )
            }
    }

    fun consumeFoliateLaunch() {
        _foliateLaunch.value = null
    }

    fun consumeReaderRoute() {
        _readerRoute.value = null
    }
}
