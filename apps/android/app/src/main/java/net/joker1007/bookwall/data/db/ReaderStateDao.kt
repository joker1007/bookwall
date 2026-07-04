package net.joker1007.bookwall.data.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert

@Dao
interface ReaderStateDao {
    @Query("SELECT * FROM reader_states WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun find(serverId: Long, bookId: Long): ReaderStateEntity?

    @Upsert
    suspend fun upsert(entity: ReaderStateEntity)

    @Query("SELECT * FROM reader_states WHERE dirty = 1")
    suspend fun dirty(): List<ReaderStateEntity>

    /** Guarded by updatedAt so a save racing the push keeps its dirty mark. */
    @Query(
        "UPDATE reader_states SET dirty = 0 " +
            "WHERE serverId = :serverId AND bookId = :bookId AND updatedAt = :updatedAt",
    )
    suspend fun clearDirty(serverId: Long, bookId: Long, updatedAt: Long)
}
