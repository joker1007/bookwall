package net.joker1007.bookwall.data.reader

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.db.EpubProgressDao
import net.joker1007.bookwall.data.db.ReaderStateDao
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.di.IoDispatcher
import javax.inject.Inject

/** Registers the offline progress flusher; behind an interface for JVM tests. */
fun interface ProgressSyncScheduler {
    fun schedule()
}

class WorkManagerProgressSyncScheduler @Inject constructor(
    private val workManager: WorkManager,
) : ProgressSyncScheduler {

    override fun schedule() {
        // CONNECTED makes WorkManager fire this when connectivity returns.
        val request = OneTimeWorkRequestBuilder<ProgressSyncWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        workManager.enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
    }

    companion object {
        const val WORK_NAME = "progress_sync"
    }
}

/**
 * Pushes reading progress that could not be synced while it was recorded
 * (offline reading of cached books). Dirty rows stay dirty on failure and the
 * worker retries with backoff.
 */
@HiltWorker
class ProgressSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val readerStateDao: ReaderStateDao,
    private val epubProgressDao: EpubProgressDao,
    private val serverRepository: ServerRepository,
    private val progressSyncRepository: ProgressSyncRepository,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(ioDispatcher) {
        var remaining = 0
        val servers = mutableMapOf<Long, OpdsServer?>()
        suspend fun serverFor(id: Long): OpdsServer? =
            servers.getOrPut(id) { serverRepository.getServer(id) }

        for (row in readerStateDao.dirty()) {
            val server = serverFor(row.serverId)
            if (server == null || !server.supportsProgressSync) {
                // Nothing to push to; drop the mark instead of retrying forever.
                readerStateDao.clearDirty(row.serverId, row.bookId, row.updatedAt)
                continue
            }
            if (progressSyncRepository.pushPageProgress(server, row.bookId, row.currentPage, 0)) {
                readerStateDao.clearDirty(row.serverId, row.bookId, row.updatedAt)
            } else {
                remaining++
            }
        }

        for (row in epubProgressDao.dirty()) {
            val server = serverFor(row.serverId)
            if (server == null || !server.supportsProgressSync) {
                epubProgressDao.clearDirty(row.serverId, row.bookId, row.updatedAt)
                continue
            }
            if (progressSyncRepository.pushEpubProgress(server, row.bookId, row.epubCfi, row.progressFraction)) {
                epubProgressDao.clearDirty(row.serverId, row.bookId, row.updatedAt)
            } else {
                remaining++
            }
        }

        if (remaining > 0) Result.retry() else Result.success()
    }
}
