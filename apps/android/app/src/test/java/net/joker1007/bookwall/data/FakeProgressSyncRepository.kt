package net.joker1007.bookwall.data

import net.joker1007.bookwall.data.reader.ProgressSyncRepository
import net.joker1007.bookwall.data.server.OpdsServer

/** Records pushed progress so tests can assert sync behaviour without a network. */
class FakeProgressSyncRepository : ProgressSyncRepository {
    data class Push(val serverId: Long, val bookId: Long, val page: Int, val pageCount: Int)

    val pushes = mutableListOf<Push>()

    override suspend fun pushPageProgress(
        server: OpdsServer,
        bookId: Long,
        page: Int,
        pageCount: Int,
    ): Boolean {
        if (!server.supportsProgressSync) return false
        pushes += Push(server.id, bookId, page, pageCount)
        return true
    }
}
