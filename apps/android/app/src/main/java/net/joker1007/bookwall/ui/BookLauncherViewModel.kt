package net.joker1007.bookwall.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.Flow
import net.joker1007.bookwall.data.epub.EpubDownloader
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.OpenBookRequest
import net.joker1007.bookwall.feature.catalog.FoliateLaunch
import net.joker1007.bookwall.data.server.ServerRepository
import javax.inject.Inject

/**
 * App-scoped launcher for opening the next EPUB when a reader rolls over. The
 * download + foliate-launch branch lives here (rather than in a screen ViewModel)
 * so the host can open the next book from either reader. [BookwallApp] observes
 * [foliateLaunch] and starts the activity.
 */
@HiltViewModel
class BookLauncherViewModel @Inject constructor(
    private val serverRepository: ServerRepository,
    private val epubDownloader: EpubDownloader,
    coordinator: BookOpenCoordinator,
) : ViewModel() {

    /** Roll-over requests raised by a reader reaching the end of a book. */
    val openRequests: Flow<OpenBookRequest> = coordinator.requests

    private val _foliateLaunch = MutableStateFlow<FoliateLaunch?>(null)
    val foliateLaunch: StateFlow<FoliateLaunch?> = _foliateLaunch.asStateFlow()

    fun openEpub(serverId: Long, book: OpdsEntry.Book) {
        val bookId = book.numericId ?: return
        viewModelScope.launch {
            val srv = serverRepository.getServer(serverId) ?: return@launch
            runCatching { epubDownloader.download(srv, book) }
                .onSuccess { file ->
                    _foliateLaunch.value = FoliateLaunch(
                        serverId = srv.id,
                        bookId = bookId,
                        title = book.title,
                        filePath = file.absolutePath,
                    )
                }
        }
    }

    fun consumeFoliateLaunch() {
        _foliateLaunch.value = null
    }
}
