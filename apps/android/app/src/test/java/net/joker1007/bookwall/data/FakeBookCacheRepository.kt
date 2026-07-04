package net.joker1007.bookwall.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.server.OpdsServer
import java.io.File

/** In-memory [BookCacheRepository] for JVM unit tests. */
class FakeBookCacheRepository : BookCacheRepository {
    val rows = MutableStateFlow<List<CachedBookEntity>>(emptyList())
    var cachedFileResult: File? = null
    val enqueued = mutableListOf<Pair<Long, Long>>()
    val deleted = mutableListOf<Pair<Long, Long>>()

    override fun observe(serverId: Long): Flow<Map<Long, CachedBookEntity>> =
        rows.map { list -> list.filter { it.serverId == serverId }.associateBy { it.bookId } }

    override fun observeAll(): Flow<List<CachedBookEntity>> = rows

    override fun observeCompletedBytes(): Flow<Long> =
        rows.map { list -> list.filter { it.status == CachedBookStatus.COMPLETED }.sumOf { it.downloadedBytes } }

    override suspend fun enqueue(server: OpdsServer, book: OpdsEntry.Book) {
        book.numericId?.let { enqueued += server.id to it }
    }

    override suspend fun cachedFile(serverId: Long, bookId: Long): File? = cachedFileResult

    override suspend fun find(serverId: Long, bookId: Long): CachedBookEntity? =
        rows.value.find { it.serverId == serverId && it.bookId == bookId }

    override suspend fun delete(serverId: Long, bookId: Long) {
        deleted += serverId to bookId
        rows.value = rows.value.filterNot { it.serverId == serverId && it.bookId == bookId }
    }

    override suspend fun deleteByServer(serverId: Long) {
        rows.value = rows.value.filterNot { it.serverId == serverId }
    }

    override suspend fun deleteAll() {
        rows.value = emptyList()
    }

    override suspend fun adoptFile(server: OpdsServer, book: OpdsEntry.Book, file: File) = Unit

    override suspend fun enforceLimit() = Unit

    override suspend fun reconcile() = Unit

    override suspend fun rescheduleDownloads() = Unit
}
