package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.server.OpdsServer

/** Reading progress fetched from a Bookwall server. */
data class RemoteEpubProgress(val cfi: String?, val fraction: Float?)

/**
 * Syncs reading progress with a Bookwall server over the OPDS namespace (HTTP
 * Basic). Calls are no-ops for servers that do not advertise the progress-sync
 * capability. Image formats push an exact page; EPUB pushes/pulls a foliate CFI
 * + percentage (both clients render with foliate-js, so CFIs interoperate).
 */
interface ProgressSyncRepository {
    /** Pushes the 0-based [page] for [bookId]. Returns true if the server accepted it. */
    suspend fun pushPageProgress(server: OpdsServer, bookId: Long, page: Int, pageCount: Int): Boolean

    /** Pushes an EPUB [cfi] + [fraction] (0..1). Returns true if the server accepted it. */
    suspend fun pushEpubProgress(server: OpdsServer, bookId: Long, cfi: String, fraction: Float): Boolean

    /** Fetches the server-side progress for [bookId], or null when unsupported / unreachable. */
    suspend fun pullEpubProgress(server: OpdsServer, bookId: Long): RemoteEpubProgress?
}

/**
 * Chooses which EPUB CFI to restore on open: the furthest progress by fraction,
 * with local winning ties (within [epsilon]) so a just-saved local position
 * isn't overridden by a slightly-stale server value. Returns null if neither side
 * has a position.
 */
fun reconcileEpubCfi(
    localCfi: String?,
    localFraction: Float?,
    remoteCfi: String?,
    remoteFraction: Float?,
    epsilon: Float = 0.001f,
): String? {
    if (localCfi == null) return remoteCfi
    if (remoteCfi == null) return localCfi
    val local = localFraction ?: 0f
    val remote = remoteFraction ?: 0f
    return if (remote > local + epsilon) remoteCfi else localCfi
}
