package net.joker1007.bookwall.feature.catalog

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.isEpub
import net.joker1007.bookwall.data.opds.isReadable
import kotlin.math.roundToInt

/** Book metadata detail shown in a bottom sheet, including server-side reading progress. */
@Composable
fun BookDetail(
    book: OpdsEntry.Book,
    onRead: (OpdsEntry.Book) -> Unit,
    modifier: Modifier = Modifier,
    localCurrentPage: Int? = null,
    epubProgress: Float? = null,
    cacheStatus: CachedBookEntity? = null,
    onDownload: ((OpdsEntry.Book) -> Unit)? = null,
    onRemoveCache: ((OpdsEntry.Book) -> Unit)? = null,
    onOpenSeries: ((String) -> Unit)? = null,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(book.title, style = MaterialTheme.typography.headlineSmall)

        if (book.authors.isNotEmpty()) {
            DetailRow("著者", book.authors.joinToString(", "))
        }
        if (book.tags.isNotEmpty()) {
            DetailRow("タグ", book.tags.joinToString(", "))
        }
        val seriesHref = book.seriesHref
        val seriesName = book.seriesName
        if (seriesName != null && seriesHref != null && onOpenSeries != null) {
            Text(
                text = "シリーズ: $seriesName",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onOpenSeries(seriesHref) }
                    .testTag(BookDetailTags.SERIES_LINK),
            )
        }
        book.format?.let { DetailRow("形式", it) }
        book.summary?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 4.dp))
        }

        val pse = book.pse
        if (pse != null && pse.pageCount > 0) {
            // Image books: page-based progress. Prefer the local reading
            // position; fall back to the server's pse:lastRead (not synced yet).
            val lastRead = localCurrentPage?.plus(1) ?: pse.lastRead ?: 0
            Text(
                text = "進捗: $lastRead / ${pse.pageCount} ページ",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
            LinearProgressIndicator(
                progress = { lastRead.toFloat() / pse.pageCount.toFloat() },
                modifier = Modifier.fillMaxWidth(),
            )
        } else if (book.isEpub && epubProgress != null) {
            // EPUB: page counts are coarse, so show a percentage instead.
            val percent = (epubProgress.coerceIn(0f, 1f) * 100).roundToInt()
            Text(
                text = "進捗: $percent%",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 8.dp),
            )
            LinearProgressIndicator(
                progress = { epubProgress.coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        if (book.isReadable) {
            Button(
                onClick = { onRead(book) },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .testTag(BookDetailTags.READ_BUTTON),
            ) {
                Text("読む")
            }
        }

        if (book.acquisitionHref != null && onDownload != null && onRemoveCache != null) {
            CacheActions(book, cacheStatus, onDownload, onRemoveCache)
        }
    }
}

@Composable
private fun CacheActions(
    book: OpdsEntry.Book,
    cache: CachedBookEntity?,
    onDownload: (OpdsEntry.Book) -> Unit,
    onRemoveCache: (OpdsEntry.Book) -> Unit,
) {
    var confirmDelete by remember { mutableStateOf(false) }

    when (cache?.status) {
        null, CachedBookStatus.FAILED -> OutlinedButton(
            onClick = { onDownload(book) },
            modifier = Modifier
                .fillMaxWidth()
                .testTag(BookDetailTags.DOWNLOAD_BUTTON),
        ) {
            Text(if (cache?.status == CachedBookStatus.FAILED) "再ダウンロード" else "ダウンロード")
        }
        CachedBookStatus.PENDING, CachedBookStatus.DOWNLOADING -> {
            if (cache.status == CachedBookStatus.DOWNLOADING && cache.totalBytes > 0) {
                LinearProgressIndicator(
                    progress = { cache.downloadedBytes.toFloat() / cache.totalBytes.toFloat() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag(BookDetailTags.DOWNLOAD_PROGRESS),
                )
            } else {
                LinearProgressIndicator(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag(BookDetailTags.DOWNLOAD_PROGRESS),
                )
            }
            OutlinedButton(
                onClick = { onRemoveCache(book) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(BookDetailTags.CANCEL_DOWNLOAD_BUTTON),
            ) {
                Text("ダウンロードをキャンセル")
            }
        }
        CachedBookStatus.COMPLETED -> OutlinedButton(
            onClick = { confirmDelete = true },
            modifier = Modifier
                .fillMaxWidth()
                .testTag(BookDetailTags.DELETE_CACHE_BUTTON),
        ) {
            Text("キャッシュを削除")
        }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("キャッシュを削除") },
            text = { Text("「${book.title}」のダウンロード済みファイルを削除しますか?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmDelete = false
                        onRemoveCache(book)
                    },
                    modifier = Modifier.testTag(BookDetailTags.DELETE_CACHE_CONFIRM),
                ) {
                    Text("削除")
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") }
            },
        )
    }
}

object BookDetailTags {
    const val READ_BUTTON = "book_detail_read"
    const val SERIES_LINK = "book_detail_series"
    const val DOWNLOAD_BUTTON = "book_detail_download"
    const val DOWNLOAD_PROGRESS = "book_detail_download_progress"
    const val CANCEL_DOWNLOAD_BUTTON = "book_detail_cancel_download"
    const val DELETE_CACHE_BUTTON = "book_detail_delete_cache"
    const val DELETE_CACHE_CONFIRM = "book_detail_delete_cache_confirm"
}

@Composable
private fun DetailRow(label: String, value: String) {
    Text(
        text = "$label: $value",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}
