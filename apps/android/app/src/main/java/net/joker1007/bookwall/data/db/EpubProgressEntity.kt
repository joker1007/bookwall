package net.joker1007.bookwall.data.db

import androidx.room.Entity

@Entity(tableName = "epub_progress", primaryKeys = ["serverId", "bookId"])
data class EpubProgressEntity(
    val serverId: Long,
    val bookId: Long,
    /** Readium Locator serialized as JSON. */
    val locatorJson: String,
    val updatedAt: Long,
)
