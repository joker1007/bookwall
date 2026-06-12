package net.joker1007.bookwall.ui

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag

/** Confirmation shown when the reader reaches the end and a next book is queued. */
@Composable
fun NextBookDialog(
    title: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    AlertDialog(
        modifier = modifier.testTag(NextBookDialogTags.ROOT),
        onDismissRequest = onDismiss,
        title = { Text("次の書籍を開きますか？") },
        text = { Text(title) },
        confirmButton = {
            TextButton(onClick = onConfirm, modifier = Modifier.testTag(NextBookDialogTags.CONFIRM)) {
                Text("開く")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("キャンセル") }
        },
    )
}

object NextBookDialogTags {
    const val ROOT = "next_book_dialog"
    const val CONFIRM = "next_book_dialog_confirm"
}
