package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.server.OpdsServer

/**
 * Pushes local reading progress to a Bookwall server (push-only). Image-based
 * formats only; EPUB position is owned by the web reader (epub_cfi) and is not
 * synced here. Calls are no-ops for servers that do not advertise the
 * progress-sync capability.
 */
interface ProgressSyncRepository {
    /**
     * Pushes the 0-based [page] for [bookId] to [server]. Returns true when the
     * server accepted the update, false when sync is unsupported or the request
     * failed (best-effort; the local state remains the source of truth).
     */
    suspend fun pushPageProgress(server: OpdsServer, bookId: Long, page: Int, pageCount: Int): Boolean
}
