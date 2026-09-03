package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.CancellationException
import net.joker1007.bookwall.data.db.CachedBookDao
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.Request
import okhttp3.Response
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import javax.inject.Provider

/**
 * Drains the cached_books PENDING queue one book at a time. The DB is the
 * queue: enqueueing more books while this runs just adds rows.
 *
 * An interrupted download keeps its part file and is resumed with a Range
 * request (If-Range guards against the server file having changed). Only an
 * attempt that made no progress counts against [MAX_RETRIES].
 */
class BookCacheDrainer(
    private val dao: CachedBookDao,
    private val fileStore: BookCacheFileStore,
    private val serverRepository: ServerRepository,
    private val clientFactory: OkHttpClientFactory,
    private val repository: Provider<BookCacheRepository>,
    private val clock: () -> Long,
) {
    suspend fun drain() {
        dao.requeueDownloading()
        while (true) {
            val row = dao.nextPending() ?: break
            val server = serverRepository.getServer(row.serverId)
            if (server == null) {
                dao.updateStatus(row.serverId, row.bookId, CachedBookStatus.FAILED)
                continue
            }
            val part = fileStore.partFileFor(row.fileName)
            val startBytes = part.length()
            try {
                download(server, row, part)
                repository.get().enforceLimit()
            } catch (e: CancelledByUser) {
                part.delete()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // IO and unexpected errors alike: retry the book, never kill the drainer.
                val current = dao.find(row.serverId, row.bookId)
                if (current == null) {
                    part.delete()
                    continue
                }
                val retries = if (part.length() > startBytes) row.retryCount else row.retryCount + 1
                val failed = retries >= MAX_RETRIES
                if (failed) part.delete()
                dao.upsert(
                    current.copy(
                        status = if (failed) CachedBookStatus.FAILED else CachedBookStatus.PENDING,
                        retryCount = retries,
                        downloadedBytes = part.length(),
                    ),
                )
            }
        }
    }

    private suspend fun download(server: OpdsServer, row: CachedBookEntity, part: File) {
        dao.updateStatus(row.serverId, row.bookId, CachedBookStatus.DOWNLOADING)
        val client = clientFactory.forServer(server)
        val offset = part.length()
        val request = Request.Builder().url(row.acquisitionUrl).apply {
            if (offset > 0) {
                header("Range", "bytes=$offset-")
                row.etag?.let { header("If-Range", it) }
            }
        }.build()

        client.newCall(request).execute().use { response ->
            val plan = plan(response, row, part, offset) ?: return@use
            if (response.code == 200 || row.etag == null) {
                dao.updateEtag(row.serverId, row.bookId, response.header("ETag")?.takeUnless { it.startsWith("W/") })
            }
            val body = response.body ?: throw IOException("Empty response body")
            var copied = plan.offset
            var lastCheck = copied
            var lastReport = 0L
            FileOutputStream(part, plan.append).use { out ->
                val source = body.byteStream()
                val buffer = ByteArray(BUFFER_SIZE)
                while (true) {
                    val read = source.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    copied += read
                    if (copied - lastCheck >= CANCEL_CHECK_BYTES) {
                        lastCheck = copied
                        // A deleted row means the user cancelled this download.
                        val current = dao.find(row.serverId, row.bookId) ?: throw CancelledByUser()
                        if (current.status != CachedBookStatus.DOWNLOADING) throw CancelledByUser()
                    }
                    val now = clock()
                    if (now - lastReport >= PROGRESS_INTERVAL_MS) {
                        lastReport = now
                        dao.updateProgress(row.serverId, row.bookId, copied, plan.total)
                    }
                }
            }
            if (plan.total > 0 && copied < plan.total) {
                throw IOException("Connection closed after $copied of ${plan.total} bytes")
            }
        }

        complete(server, row, part)
    }

    private class Plan(val offset: Long, val append: Boolean, val total: Long)

    /** Decides where the response's bytes go; null means the part file is already complete. */
    private fun plan(response: Response, row: CachedBookEntity, part: File, offset: Long): Plan? = when (response.code) {
        200 -> Plan(
            offset = 0,
            append = false,
            total = response.body?.contentLength()?.takeIf { it > 0 } ?: row.totalBytes,
        )
        206 -> {
            val range = ContentRange.parse(response.header("Content-Range"))
                ?: throw IOException("206 without a usable Content-Range")
            if (range.start != offset) throw IOException("Resume offset mismatch: asked $offset, got ${range.start}")
            Plan(offset = offset, append = true, total = range.total ?: row.totalBytes)
        }
        416 -> {
            val total = ContentRange.parseUnsatisfiable(response.header("Content-Range"))
            if (total != null && total == offset) {
                null
            } else {
                part.delete()
                throw IOException("Range not satisfiable; restarting from scratch")
            }
        }
        else -> throw IOException("Download failed: HTTP ${response.code}")
    }

    private suspend fun complete(server: OpdsServer, row: CachedBookEntity, part: File) {
        val current = dao.find(row.serverId, row.bookId) ?: throw CancelledByUser()
        val file = fileStore.fileFor(row.fileName)
        if (!part.renameTo(file)) throw IOException("Failed to move ${part.name} into place")
        val thumbName = downloadThumbnail(server, row)
        dao.upsert(
            current.copy(
                status = CachedBookStatus.COMPLETED,
                downloadedBytes = file.length(),
                totalBytes = file.length(),
                thumbnailFileName = thumbName,
                lastAccessedAt = clock(),
            ),
        )
    }

    /** Best effort; a missing thumbnail never fails the book download. */
    private fun downloadThumbnail(server: OpdsServer, row: CachedBookEntity): String? {
        val url = row.thumbnailUrl ?: return null
        return runCatching {
            val name = fileStore.thumbFileName(row.serverId, row.bookId)
            clientFactory.forServer(server).newCall(Request.Builder().url(url).build()).execute().use { response ->
                if (!response.isSuccessful) return null
                val body = response.body ?: return null
                fileStore.fileFor(name).outputStream().use { out -> body.byteStream().copyTo(out) }
            }
            name
        }.getOrNull()
    }

    private class CancelledByUser : Exception()

    private class ContentRange(val start: Long, val total: Long?) {
        companion object {
            private val SATISFIED = Regex("""bytes\s+(\d+)-(\d+)/(\d+|\*)""")
            private val UNSATISFIED = Regex("""bytes\s+\*/(\d+)""")

            fun parse(header: String?): ContentRange? {
                val match = SATISFIED.matchEntire(header?.trim() ?: return null) ?: return null
                return ContentRange(match.groupValues[1].toLong(), match.groupValues[3].toLongOrNull())
            }

            fun parseUnsatisfiable(header: String?): Long? {
                val match = UNSATISFIED.matchEntire(header?.trim() ?: return null) ?: return null
                return match.groupValues[1].toLong()
            }
        }
    }

    private companion object {
        const val MAX_RETRIES = 3
        const val BUFFER_SIZE = 64 * 1024
        const val CANCEL_CHECK_BYTES = 1024L * 1024
        const val PROGRESS_INTERVAL_MS = 500L
    }
}
