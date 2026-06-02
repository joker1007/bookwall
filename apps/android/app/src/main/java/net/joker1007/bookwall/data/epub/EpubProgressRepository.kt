package net.joker1007.bookwall.data.epub

import net.joker1007.bookwall.data.db.EpubProgressDao
import net.joker1007.bookwall.data.db.EpubProgressEntity
import org.json.JSONObject
import org.readium.r2.shared.publication.Locator
import javax.inject.Inject

class EpubProgressRepository @Inject constructor(
    private val dao: EpubProgressDao,
    private val clock: () -> Long,
) {
    suspend fun load(serverId: Long, bookId: Long): Locator? =
        dao.find(serverId, bookId)?.let { entity ->
            runCatching { Locator.fromJSON(JSONObject(entity.locatorJson)) }.getOrNull()
        }

    suspend fun save(serverId: Long, bookId: Long, locator: Locator) {
        dao.upsert(
            EpubProgressEntity(
                serverId = serverId,
                bookId = bookId,
                locatorJson = locator.toJSON().toString(),
                updatedAt = clock(),
            ),
        )
    }
}
