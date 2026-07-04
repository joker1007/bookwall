package net.joker1007.bookwall.data.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert

@Dao
interface EpubProgressDao {
    @Query("SELECT * FROM epub_progress WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun find(serverId: Long, bookId: Long): EpubProgressEntity?

    @Upsert
    suspend fun upsert(entity: EpubProgressEntity)

    @Query("SELECT * FROM epub_progress WHERE dirty = 1")
    suspend fun dirty(): List<EpubProgressEntity>

    /** Guarded by updatedAt so a save racing the push keeps its dirty mark. */
    @Query(
        "UPDATE epub_progress SET dirty = 0 " +
            "WHERE serverId = :serverId AND bookId = :bookId AND updatedAt = :updatedAt",
    )
    suspend fun clearDirty(serverId: Long, bookId: Long, updatedAt: Long)
}
