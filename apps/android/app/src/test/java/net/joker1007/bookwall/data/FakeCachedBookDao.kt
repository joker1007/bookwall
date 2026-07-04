package net.joker1007.bookwall.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import net.joker1007.bookwall.data.db.CachedBookDao
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus

/** In-memory [CachedBookDao] for JVM unit tests. */
class FakeCachedBookDao : CachedBookDao {
    val rows = MutableStateFlow<List<CachedBookEntity>>(emptyList())

    override fun observeByServer(serverId: Long): Flow<List<CachedBookEntity>> =
        rows.map { list -> list.filter { it.serverId == serverId } }

    override fun observeAll(): Flow<List<CachedBookEntity>> =
        rows.map { list -> list.sortedByDescending { it.createdAt } }

    override suspend fun find(serverId: Long, bookId: Long): CachedBookEntity? =
        rows.value.find { it.serverId == serverId && it.bookId == bookId }

    override suspend fun upsert(entity: CachedBookEntity) {
        rows.value = rows.value.filterNot {
            it.serverId == entity.serverId && it.bookId == entity.bookId
        } + entity
    }

    override suspend fun nextPending(): CachedBookEntity? =
        rows.value.filter { it.status == CachedBookStatus.PENDING }.minByOrNull { it.createdAt }

    override suspend fun updateStatus(serverId: Long, bookId: Long, status: CachedBookStatus) {
        update(serverId, bookId) { it.copy(status = status) }
    }

    override suspend fun updateProgress(serverId: Long, bookId: Long, downloadedBytes: Long, totalBytes: Long) {
        update(serverId, bookId) { it.copy(downloadedBytes = downloadedBytes, totalBytes = totalBytes) }
    }

    override suspend fun touch(serverId: Long, bookId: Long, now: Long) {
        update(serverId, bookId) { it.copy(lastAccessedAt = now) }
    }

    override fun observeCompletedBytes(): Flow<Long> =
        rows.map { list -> list.filter { it.status == CachedBookStatus.COMPLETED }.sumOf { it.downloadedBytes } }

    override suspend fun completedByLruAsc(): List<CachedBookEntity> =
        rows.value.filter { it.status == CachedBookStatus.COMPLETED }.sortedBy { it.lastAccessedAt }

    override suspend fun all(): List<CachedBookEntity> = rows.value

    override suspend fun delete(serverId: Long, bookId: Long) {
        rows.value = rows.value.filterNot { it.serverId == serverId && it.bookId == bookId }
    }

    private fun update(serverId: Long, bookId: Long, transform: (CachedBookEntity) -> CachedBookEntity) {
        rows.value = rows.value.map {
            if (it.serverId == serverId && it.bookId == bookId) transform(it) else it
        }
    }
}
