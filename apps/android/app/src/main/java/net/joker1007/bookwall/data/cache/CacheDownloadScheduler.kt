package net.joker1007.bookwall.data.cache

import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import javax.inject.Inject

/** Registers the background download drainer; behind an interface for JVM tests. */
interface CacheDownloadScheduler {
    fun schedule(wifiOnly: Boolean)

    /** Constraints of enqueued work cannot change, so cancel and re-register. */
    fun reschedule(wifiOnly: Boolean)
}

class WorkManagerCacheDownloadScheduler @Inject constructor(
    private val workManager: WorkManager,
) : CacheDownloadScheduler {

    override fun schedule(wifiOnly: Boolean) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<BookCacheDownloadWorker>()
            .setConstraints(constraints)
            .build()
        workManager.enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
    }

    override fun reschedule(wifiOnly: Boolean) {
        workManager.cancelUniqueWork(WORK_NAME)
        schedule(wifiOnly)
    }

    companion object {
        const val WORK_NAME = "book_cache_download"
    }
}
