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
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.di.IoDispatcher
import net.joker1007.bookwall.network.OkHttpClientFactory
import javax.inject.Provider

/**
 * Foreground shell around [BookCacheDrainer]. The unique work policy (KEEP)
 * makes sure a single drainer is active.
 */
@HiltWorker
class BookCacheDownloadWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    dao: CachedBookDao,
    fileStore: BookCacheFileStore,
    serverRepository: ServerRepository,
    clientFactory: OkHttpClientFactory,
    repository: Provider<BookCacheRepository>,
    clock: () -> Long,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : CoroutineWorker(context, params) {

    private val drainer = BookCacheDrainer(dao, fileStore, serverRepository, clientFactory, repository, clock)

    override suspend fun doWork(): Result = withContext(ioDispatcher) {
        runCatching { setForeground(getForegroundInfo()) }
        drainer.drain()
        Result.success()
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

    private companion object {
        const val CHANNEL_ID = "downloads"
        const val NOTIFICATION_ID = 1001
    }
}
