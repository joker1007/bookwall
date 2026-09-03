package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.db.CachedBookDao
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.opds.resolveOpdsHref
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.di.IoDispatcher
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookCacheRepositoryImpl @Inject constructor(
    private val dao: CachedBookDao,
    private val fileStore: BookCacheFileStore,
    private val settingsRepository: CacheSettingsRepository,
    private val scheduler: CacheDownloadScheduler,
    private val clock: () -> Long,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : BookCacheRepository {

    override fun observe(serverId: Long): Flow<Map<Long, CachedBookEntity>> =
        dao.observeByServer(serverId).map { rows -> rows.associateBy { it.bookId } }

    override fun observeAll(): Flow<List<CachedBookEntity>> = dao.observeAll()

    override fun observeCompletedBytes(): Flow<Long> = dao.observeCompletedBytes()

    override suspend fun enqueue(server: OpdsServer, book: OpdsEntry.Book) {
        val bookId = book.numericId ?: return
        val href = book.acquisitionHref ?: return
        val url = resolveOpdsHref(server.baseUrl, href) ?: return
        if (dao.find(server.id, bookId) != null) return

        val thumbHref = book.thumbnailHref ?: book.imageHref
        val now = clock()
        dao.upsert(
            CachedBookEntity(
                serverId = server.id,
                bookId = bookId,
                title = book.title,
                authors = book.authors.joinToString(", "),
                format = book.acquisitionType,
                pageCount = book.pse?.pageCount ?: 0,
                fileName = fileStore.bookFileName(server.id, bookId, book.acquisitionType),
                thumbnailFileName = null,
                status = CachedBookStatus.PENDING,
                downloadedBytes = 0,
                totalBytes = book.fileSize ?: 0,
                retryCount = 0,
                acquisitionUrl = url,
                thumbnailUrl = thumbHref?.let { resolveOpdsHref(server.baseUrl, it) },
                createdAt = now,
                lastAccessedAt = now,
            ),
        )
        scheduleWork()
    }

    override suspend fun cachedFile(serverId: Long, bookId: Long): File? = withContext(ioDispatcher) {
        val row = dao.find(serverId, bookId) ?: return@withContext null
        if (row.status != CachedBookStatus.COMPLETED) return@withContext null
        val file = fileStore.fileFor(row.fileName)
        if (!file.exists()) {
            dao.delete(serverId, bookId)
            return@withContext null
        }
        dao.touch(serverId, bookId, clock())
        file
    }

    override suspend fun find(serverId: Long, bookId: Long): CachedBookEntity? = dao.find(serverId, bookId)

    override suspend fun delete(serverId: Long, bookId: Long) = withContext(ioDispatcher) {
        // The worker notices the missing row mid-download and cleans up its part file.
        val row = dao.find(serverId, bookId) ?: return@withContext
        dao.delete(serverId, bookId)
        deleteFiles(row)
    }

    override suspend fun deleteByServer(serverId: Long) = withContext(ioDispatcher) {
        dao.all().filter { it.serverId == serverId }.forEach { row ->
            dao.delete(row.serverId, row.bookId)
            deleteFiles(row)
        }
    }

    override suspend fun deleteAll() = withContext(ioDispatcher) {
        dao.all().forEach { row ->
            dao.delete(row.serverId, row.bookId)
            deleteFiles(row)
        }
    }

    override suspend fun adoptFile(server: OpdsServer, book: OpdsEntry.Book, file: File) {
        val bookId = book.numericId ?: return
        val url = book.acquisitionHref?.let { resolveOpdsHref(server.baseUrl, it) } ?: return
        val existing = dao.find(server.id, bookId)
        if (existing?.status == CachedBookStatus.COMPLETED) return

        withContext(ioDispatcher) {
            val fileName = fileStore.bookFileName(server.id, bookId, book.acquisitionType)
            file.copyTo(fileStore.fileFor(fileName), overwrite = true)
            val thumbHref = book.thumbnailHref ?: book.imageHref
            val now = clock()
            dao.upsert(
                CachedBookEntity(
                    serverId = server.id,
                    bookId = bookId,
                    title = book.title,
                    authors = book.authors.joinToString(", "),
                    format = book.acquisitionType,
                    pageCount = book.pse?.pageCount ?: 0,
                    fileName = fileName,
                    thumbnailFileName = null,
                    status = CachedBookStatus.COMPLETED,
                    downloadedBytes = fileStore.fileFor(fileName).length(),
                    totalBytes = fileStore.fileFor(fileName).length(),
                    retryCount = 0,
                    acquisitionUrl = url,
                    thumbnailUrl = thumbHref?.let { resolveOpdsHref(server.baseUrl, it) },
                    createdAt = now,
                    lastAccessedAt = now,
                ),
            )
        }
        enforceLimit()
    }

    override suspend fun enforceLimit() = withContext(ioDispatcher) {
        val max = settingsRepository.settings.first().maxCacheBytes
        if (max <= 0) return@withContext
        val completed = dao.completedByLruAsc()
        var total = completed.sumOf { fileStore.fileFor(it.fileName).length() }
        for (row in completed) {
            if (total <= max) break
            total -= fileStore.fileFor(row.fileName).length()
            dao.delete(row.serverId, row.bookId)
            deleteFiles(row)
        }
    }

    override suspend fun reconcile() = withContext(ioDispatcher) {
        val rows = dao.all()
        var hasPending = false
        for (row in rows) {
            when (row.status) {
                CachedBookStatus.DOWNLOADING -> {
                    // Left over from a killed process; the part file is resumed with a Range request.
                    dao.updateProgress(row.serverId, row.bookId, fileStore.partFileFor(row.fileName).length(), row.totalBytes)
                    dao.updateStatus(row.serverId, row.bookId, CachedBookStatus.PENDING)
                    hasPending = true
                }
                CachedBookStatus.COMPLETED ->
                    if (!fileStore.fileFor(row.fileName).exists()) dao.delete(row.serverId, row.bookId)
                CachedBookStatus.PENDING -> hasPending = true
                CachedBookStatus.FAILED -> Unit
            }
        }
        deleteOrphanFiles(rows)
        if (hasPending) scheduleWork()
    }

    override suspend fun rescheduleDownloads() {
        scheduler.reschedule(settingsRepository.settings.first().wifiOnly)
    }

    private suspend fun scheduleWork() {
        scheduler.schedule(settingsRepository.settings.first().wifiOnly)
    }

    private fun deleteFiles(row: CachedBookEntity) {
        fileStore.fileFor(row.fileName).delete()
        fileStore.partFileFor(row.fileName).delete()
        row.thumbnailFileName?.let { fileStore.fileFor(it).delete() }
    }

    private fun deleteOrphanFiles(rows: List<CachedBookEntity>) {
        val known = buildSet {
            rows.forEach { row ->
                add(fileStore.fileFor(row.fileName))
                add(fileStore.partFileFor(row.fileName))
                row.thumbnailFileName?.let { add(fileStore.fileFor(it)) }
            }
        }
        fileStore.root.walkTopDown()
            .filter { it.isFile && it !in known }
            .forEach { it.delete() }
    }
}
