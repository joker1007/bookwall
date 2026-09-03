package net.joker1007.bookwall.data.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface CachedBookDao {
    @Query("SELECT * FROM cached_books WHERE serverId = :serverId")
    fun observeByServer(serverId: Long): Flow<List<CachedBookEntity>>

    @Query("SELECT * FROM cached_books ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<CachedBookEntity>>

    @Query("SELECT * FROM cached_books WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun find(serverId: Long, bookId: Long): CachedBookEntity?

    @Upsert
    suspend fun upsert(entity: CachedBookEntity)

    @Query("SELECT * FROM cached_books WHERE status = 'PENDING' ORDER BY createdAt LIMIT 1")
    suspend fun nextPending(): CachedBookEntity?

    @Query("UPDATE cached_books SET status = :status WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun updateStatus(serverId: Long, bookId: Long, status: CachedBookStatus)

    @Query(
        "UPDATE cached_books SET downloadedBytes = :downloadedBytes, totalBytes = :totalBytes " +
            "WHERE serverId = :serverId AND bookId = :bookId",
    )
    suspend fun updateProgress(serverId: Long, bookId: Long, downloadedBytes: Long, totalBytes: Long)

    @Query("UPDATE cached_books SET etag = :etag WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun updateEtag(serverId: Long, bookId: Long, etag: String?)

    /** Rows left DOWNLOADING by a stopped worker; their part files are resumed. */
    @Query("UPDATE cached_books SET status = 'PENDING' WHERE status = 'DOWNLOADING'")
    suspend fun requeueDownloading()

    @Query("UPDATE cached_books SET lastAccessedAt = :now WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun touch(serverId: Long, bookId: Long, now: Long)

    @Query("SELECT COALESCE(SUM(downloadedBytes), 0) FROM cached_books WHERE status = 'COMPLETED'")
    fun observeCompletedBytes(): Flow<Long>

    @Query("SELECT * FROM cached_books WHERE status = 'COMPLETED' ORDER BY lastAccessedAt")
    suspend fun completedByLruAsc(): List<CachedBookEntity>

    @Query("SELECT * FROM cached_books")
    suspend fun all(): List<CachedBookEntity>

    @Query("DELETE FROM cached_books WHERE serverId = :serverId AND bookId = :bookId")
    suspend fun delete(serverId: Long, bookId: Long)
}
