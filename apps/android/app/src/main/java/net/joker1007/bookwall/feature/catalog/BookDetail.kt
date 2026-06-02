package net.joker1007.bookwall.feature.catalog

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
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
    }
}

object BookDetailTags {
    const val READ_BUTTON = "book_detail_read"
}

@Composable
private fun DetailRow(label: String, value: String) {
    Text(
        text = "$label: $value",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}
