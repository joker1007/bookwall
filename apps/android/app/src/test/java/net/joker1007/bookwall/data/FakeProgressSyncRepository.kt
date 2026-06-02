package net.joker1007.bookwall.data

import net.joker1007.bookwall.data.reader.ProgressSyncRepository
import net.joker1007.bookwall.data.reader.RemoteEpubProgress
import net.joker1007.bookwall.data.server.OpdsServer

/** Records pushed progress so tests can assert sync behaviour without a network. */
class FakeProgressSyncRepository : ProgressSyncRepository {
    data class Push(val serverId: Long, val bookId: Long, val page: Int, val pageCount: Int)
    data class EpubPush(val serverId: Long, val bookId: Long, val cfi: String, val fraction: Float)

    val pushes = mutableListOf<Push>()
    val epubPushes = mutableListOf<EpubPush>()
    var remoteEpubProgress: RemoteEpubProgress? = null

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

    override suspend fun pushEpubProgress(
        server: OpdsServer,
        bookId: Long,
        cfi: String,
        fraction: Float,
    ): Boolean {
        if (!server.supportsProgressSync) return false
        epubPushes += EpubPush(server.id, bookId, cfi, fraction)
        return true
    }

    override suspend fun pullEpubProgress(server: OpdsServer, bookId: Long): RemoteEpubProgress? =
        if (server.supportsProgressSync) remoteEpubProgress else null
}
