package net.joker1007.bookwall.data.db

import androidx.room.Entity

@Entity(tableName = "reader_states", primaryKeys = ["serverId", "bookId"])
data class ReaderStateEntity(
    val serverId: Long,
    val bookId: Long,
    val currentPage: Int,
    val direction: String,
    val spreadEnabled: Boolean,
    val updatedAt: Long,
)
