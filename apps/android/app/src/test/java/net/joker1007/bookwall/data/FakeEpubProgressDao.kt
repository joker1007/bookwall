package net.joker1007.bookwall.data

import net.joker1007.bookwall.data.db.EpubProgressDao
import net.joker1007.bookwall.data.db.EpubProgressEntity

/** In-memory [EpubProgressDao] for unit tests. */
class FakeEpubProgressDao : EpubProgressDao {
    private val rows = mutableMapOf<Pair<Long, Long>, EpubProgressEntity>()

    override suspend fun find(serverId: Long, bookId: Long): EpubProgressEntity? =
        rows[serverId to bookId]

    override suspend fun upsert(entity: EpubProgressEntity) {
        rows[entity.serverId to entity.bookId] = entity
    }
}
