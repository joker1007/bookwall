package net.joker1007.bookwall.data.db

import androidx.room.Entity

@Entity(tableName = "reader_states", primaryKeys = ["serverId", "bookId"])
data class ReaderStateEntity(
    val serverId: Long,
    val bookId: Long,
    val currentPage: Int,
    val direction: String,
    val spreadMode: String,
    val updatedAt: Long,
    /** True while the latest progress has not been pushed to the server. */
    val dirty: Boolean = false,
)
