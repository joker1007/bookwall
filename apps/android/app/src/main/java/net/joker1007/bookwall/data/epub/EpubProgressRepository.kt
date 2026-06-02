package net.joker1007.bookwall.data.epub

import net.joker1007.bookwall.data.db.EpubProgressDao
import net.joker1007.bookwall.data.db.EpubProgressEntity
import javax.inject.Inject

/** Locally saved EPUB reading position (foliate CFI + 0..1 progress fraction). */
data class EpubProgress(val cfi: String, val fraction: Float)

class EpubProgressRepository @Inject constructor(
    private val dao: EpubProgressDao,
    private val clock: () -> Long,
) {
    suspend fun load(serverId: Long, bookId: Long): EpubProgress? =
        dao.find(serverId, bookId)?.let { EpubProgress(it.epubCfi, it.progressFraction) }

    suspend fun save(serverId: Long, bookId: Long, cfi: String, fraction: Float) {
        dao.upsert(
            EpubProgressEntity(
                serverId = serverId,
                bookId = bookId,
                epubCfi = cfi,
                progressFraction = fraction,
                updatedAt = clock(),
            ),
        )
    }
}
