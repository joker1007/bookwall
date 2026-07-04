package net.joker1007.bookwall.feature.downloads

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.cache.BookCacheFileStore
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.server.ServerRepository
import java.io.File
import javax.inject.Inject

data class DownloadedBookUi(
    val entity: CachedBookEntity,
    /** Locally saved thumbnail, or null when none was downloaded. */
    val thumbnail: File?,
)

data class DownloadedSection(
    val serverId: Long,
    val serverName: String,
    val books: List<DownloadedBookUi>,
)

/** Lists cached books grouped by server. Works fully offline from local rows. */
@HiltViewModel
class DownloadedBooksViewModel @Inject constructor(
    private val bookCacheRepository: BookCacheRepository,
    private val fileStore: BookCacheFileStore,
    serverRepository: ServerRepository,
) : ViewModel() {

    val sections: StateFlow<List<DownloadedSection>> =
        combine(bookCacheRepository.observeAll(), serverRepository.observeServers()) { rows, servers ->
            val namesById = servers.associate { it.id to it.name }
            rows.groupBy { it.serverId }.map { (serverId, books) ->
                DownloadedSection(
                    serverId = serverId,
                    serverName = namesById[serverId] ?: "サーバー $serverId",
                    books = books.map { row ->
                        DownloadedBookUi(
                            entity = row,
                            thumbnail = row.thumbnailFileName
                                ?.let { fileStore.fileFor(it) }
                                ?.takeIf { it.exists() },
                        )
                    },
                )
            }.sortedBy { it.serverName.lowercase() }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun delete(entity: CachedBookEntity) {
        viewModelScope.launch { bookCacheRepository.delete(entity.serverId, entity.bookId) }
    }
}
