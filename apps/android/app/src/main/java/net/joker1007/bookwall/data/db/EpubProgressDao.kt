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
}
