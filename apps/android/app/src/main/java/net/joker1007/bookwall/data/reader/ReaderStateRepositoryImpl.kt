package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.db.ReaderStateDao
import net.joker1007.bookwall.data.db.ReaderStateEntity
import javax.inject.Inject

class ReaderStateRepositoryImpl @Inject constructor(
    private val dao: ReaderStateDao,
    private val clock: () -> Long,
) : ReaderStateRepository {

    override suspend fun load(serverId: Long, bookId: Long): ReaderState? =
        dao.find(serverId, bookId)?.let { e ->
            ReaderState(
                currentPage = e.currentPage,
                direction = runCatching { ReadingDirection.valueOf(e.direction) }
                    .getOrDefault(ReadingDirection.RTL),
                spreadEnabled = e.spreadEnabled,
            )
        }

    override suspend fun save(serverId: Long, bookId: Long, state: ReaderState) {
        dao.upsert(
            ReaderStateEntity(
                serverId = serverId,
                bookId = bookId,
                currentPage = state.currentPage,
                direction = state.direction.name,
                spreadEnabled = state.spreadEnabled,
                updatedAt = clock(),
                dirty = true,
            ),
        )
    }

    override suspend fun markSynced(serverId: Long, bookId: Long) {
        dao.find(serverId, bookId)?.let { dao.clearDirty(serverId, bookId, it.updatedAt) }
    }
}
