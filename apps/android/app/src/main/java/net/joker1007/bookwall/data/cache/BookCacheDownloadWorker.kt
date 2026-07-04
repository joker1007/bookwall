package net.joker1007.bookwall.data.cache

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.db.CachedBookDao
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.di.IoDispatcher
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.Request
import java.io.IOException
import javax.inject.Provider

/**
 * Drains the cached_books PENDING queue one book at a time. The DB is the
 * queue: enqueueing more books while this runs just adds rows, and the unique
 * work policy (KEEP) makes sure a single drainer is active.
 */
@HiltWorker
class BookCacheDownloadWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val dao: CachedBookDao,
    private val fileStore: BookCacheFileStore,
    private val serverRepository: ServerRepository,
    private val clientFactory: OkHttpClientFactory,
    private val repository: Provider<BookCacheRepository>,
    private val clock: () -> Long,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(ioDispatcher) {
        runCatching { setForeground(getForegroundInfo()) }
        while (true) {
            val row = dao.nextPending() ?: break
            val server = serverRepository.getServer(row.serverId)
            if (server == null) {
                dao.updateStatus(row.serverId, row.bookId, CachedBookStatus.FAILED)
                continue
            }
            try {
                download(server, row)
                repository.get().enforceLimit()
            } catch (e: CancelledByUser) {
                fileStore.partFileFor(row.fileName).delete()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                // IO and unexpected errors alike: retry the book, never kill the drainer.
                fileStore.partFileFor(row.fileName).delete()
                if (dao.find(row.serverId, row.bookId) == null) continue
                val retries = row.retryCount + 1
                dao.upsert(
                    row.copy(
                        status = if (retries < MAX_RETRIES) CachedBookStatus.PENDING else CachedBookStatus.FAILED,
                        retryCount = retries,
                        downloadedBytes = 0,
                    ),
                )
            }
        }
        Result.success()
    }

    private suspend fun download(server: OpdsServer, row: CachedBookEntity) {
        dao.updateStatus(row.serverId, row.bookId, CachedBookStatus.DOWNLOADING)
        val client = clientFactory.forServer(server)
        val part = fileStore.partFileFor(row.fileName)

        client.newCall(Request.Builder().url(row.acquisitionUrl).build()).execute().use { response ->
            if (!response.isSuccessful) throw IOException("Download failed: HTTP ${response.code}")
            val body = response.body ?: throw IOException("Empty response body")
            val total = body.contentLength().takeIf { it > 0 } ?: row.totalBytes
            var copied = 0L
            var lastCheck = 0L
            var lastReport = 0L
            part.outputStream().use { out ->
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
                        dao.updateProgress(row.serverId, row.bookId, copied, total)
                    }
                }
            }
        }

        if (dao.find(row.serverId, row.bookId) == null) throw CancelledByUser()
        val file = fileStore.fileFor(row.fileName)
        if (!part.renameTo(file)) throw IOException("Failed to move ${part.name} into place")
        val thumbName = downloadThumbnail(server, row)
        dao.upsert(
            row.copy(
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

    override suspend fun getForegroundInfo(): ForegroundInfo {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "ダウンロード", NotificationManager.IMPORTANCE_LOW),
        )
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("書籍をダウンロード中")
            .setOngoing(true)
            .setProgress(0, 0, true)
            .build()
        return ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    }

    private class CancelledByUser : Exception()

    private companion object {
        const val MAX_RETRIES = 3
        const val BUFFER_SIZE = 64 * 1024
        const val CANCEL_CHECK_BYTES = 1024L * 1024
        const val PROGRESS_INTERVAL_MS = 500L
        const val CHANNEL_ID = "downloads"
        const val NOTIFICATION_ID = 1001
    }
}
