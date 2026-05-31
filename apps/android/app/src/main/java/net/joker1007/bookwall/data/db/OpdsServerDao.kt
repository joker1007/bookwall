package net.joker1007.bookwall.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface OpdsServerDao {
    @Query("SELECT * FROM opds_servers ORDER BY name COLLATE NOCASE")
    fun observeAll(): Flow<List<OpdsServerEntity>>

    @Query("SELECT * FROM opds_servers WHERE id = :id")
    suspend fun findById(id: Long): OpdsServerEntity?

    @Insert
    suspend fun insert(entity: OpdsServerEntity): Long

    @Update
    suspend fun update(entity: OpdsServerEntity)

    @Query("DELETE FROM opds_servers WHERE id = :id")
    suspend fun deleteById(id: Long)
}
