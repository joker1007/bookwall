package net.joker1007.bookwall.feature.downloads

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DownloadedBooksScreen(
    onOpenBook: (CachedBookEntity) -> Unit,
    onBack: () -> Unit,
    viewModel: DownloadedBooksViewModel = hiltViewModel(),
) {
    val sections by viewModel.sections.collectAsState()
    var pendingDelete by remember { mutableStateOf<CachedBookEntity?>(null) }

    Scaffold(
        modifier = Modifier.testTag(DownloadsTags.ROOT),
        topBar = {
            TopAppBar(
                title = { Text("ダウンロード済み") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
            )
        },
    ) { padding ->
        if (sections.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "ダウンロード済みの書籍はありません",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.testTag(DownloadsTags.EMPTY_MESSAGE),
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .testTag(DownloadsTags.LIST),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                sections.forEach { section ->
                    item(key = "server_${section.serverId}") {
                        Text(
                            text = section.serverName,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }
                    items(section.books, key = { "${it.entity.serverId}_${it.entity.bookId}" }) { book ->
                        DownloadedBookRow(
                            book = book,
                            onClick = { onOpenBook(book.entity) },
                            onDelete = { pendingDelete = book.entity },
                        )
                    }
                }
            }
        }
    }

    pendingDelete?.let { entity ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("キャッシュを削除") },
            text = { Text("「${entity.title}」のダウンロード済みファイルを削除しますか?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.delete(entity)
                        pendingDelete = null
                    },
                    modifier = Modifier.testTag(DownloadsTags.DELETE_CONFIRM),
                ) {
                    Text("削除")
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("キャンセル") }
            },
        )
    }
}

@Composable
private fun DownloadedBookRow(
    book: DownloadedBookUi,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val entity = book.entity
    val openable = entity.status == CachedBookStatus.COMPLETED
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = openable, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (book.thumbnail != null) {
            // A plain file model: the default Coil loader handles it offline.
            AsyncImage(
                model = book.thumbnail,
                contentDescription = null,
                modifier = Modifier.size(width = 48.dp, height = 68.dp),
            )
        } else {
            Box(
                modifier = Modifier
                    .size(width = 48.dp, height = 68.dp)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.MenuBook,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(entity.title, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (entity.authors.isNotEmpty()) {
                Text(
                    entity.authors,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = statusLabel(entity),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(
            onClick = onDelete,
            modifier = Modifier.testTag(DownloadsTags.deleteTag(entity.serverId, entity.bookId)),
        ) {
            Icon(Icons.Default.Delete, contentDescription = "削除")
        }
    }
}

private fun statusLabel(entity: CachedBookEntity): String = when (entity.status) {
    CachedBookStatus.COMPLETED -> formatBytes(entity.downloadedBytes)
    CachedBookStatus.DOWNLOADING, CachedBookStatus.PENDING -> "ダウンロード中"
    CachedBookStatus.FAILED -> "ダウンロード失敗"
}

private fun formatBytes(bytes: Long): String {
    var value = bytes.toDouble()
    val units = listOf("B", "KB", "MB", "GB")
    var index = 0
    while (value >= 1024 && index < units.lastIndex) {
        value /= 1024
        index++
    }
    return if (index == 0) "${bytes}B" else "%.1f%s".format(value, units[index])
}

object DownloadsTags {
    const val ROOT = "downloads_root"
    const val LIST = "downloads_list"
    const val EMPTY_MESSAGE = "downloads_empty"
    const val DELETE_CONFIRM = "downloads_delete_confirm"
    fun deleteTag(serverId: Long, bookId: Long) = "downloads_delete_${serverId}_$bookId"
}
