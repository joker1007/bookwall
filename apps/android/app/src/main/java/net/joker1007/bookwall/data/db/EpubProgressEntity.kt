package net.joker1007.bookwall.data.db

import androidx.room.Entity

@Entity(tableName = "epub_progress", primaryKeys = ["serverId", "bookId"])
data class EpubProgressEntity(
    val serverId: Long,
    val bookId: Long,
    /** foliate-js EPUB CFI (interoperable with the web reader). */
    val epubCfi: String,
    /** Reading progress 0..1 (foliate's relocate fraction), for sync reconciliation. */
    val progressFraction: Float,
    val updatedAt: Long,
)
