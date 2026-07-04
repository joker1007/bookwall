package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.flow.Flow
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.server.OpdsServer
import java.io.File

/** Manages offline book file caching: download queue, LRU eviction, lookup. */
interface BookCacheRepository {
    /** Cache rows for one server, keyed by bookId; drives catalog badges. */
    fun observe(serverId: Long): Flow<Map<Long, CachedBookEntity>>

    fun observeAll(): Flow<List<CachedBookEntity>>

    fun observeCompletedBytes(): Flow<Long>

    /** Queues a background download; no-op if already queued or cached. */
    suspend fun enqueue(server: OpdsServer, book: OpdsEntry.Book)

    /**
     * The cached file if fully downloaded, bumping its LRU timestamp. Open
     * cached books through this so eviction never removes what is being read.
     */
    suspend fun cachedFile(serverId: Long, bookId: Long): File?

    suspend fun find(serverId: Long, bookId: Long): CachedBookEntity?

    /** Cancels a pending/running download, or removes a cached file. */
    suspend fun delete(serverId: Long, bookId: Long)

    /** Removes every cached book of a server (called when the server is deleted). */
    suspend fun deleteByServer(serverId: Long)

    suspend fun deleteAll()

    /** Registers an already-downloaded file (e.g. a foreground EPUB download) as cached. */
    suspend fun adoptFile(server: OpdsServer, book: OpdsEntry.Book, file: File)

    /** Evicts least-recently-opened books until the total fits the configured limit. */
    suspend fun enforceLimit()

    /** Startup pass: drop orphans, resume interrupted downloads. */
    suspend fun reconcile()

    /** Re-registers the download work, e.g. after the Wi-Fi-only setting changed. */
    suspend fun rescheduleDownloads()
}
