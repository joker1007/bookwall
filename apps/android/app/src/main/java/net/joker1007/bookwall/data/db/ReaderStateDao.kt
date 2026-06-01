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
}
