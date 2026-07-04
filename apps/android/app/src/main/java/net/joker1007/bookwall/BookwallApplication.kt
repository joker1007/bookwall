package net.joker1007.bookwall

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.reader.ProgressSyncScheduler
import javax.inject.Inject

@HiltAndroidApp
class BookwallApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory

    @Inject lateinit var bookCacheRepository: BookCacheRepository

    @Inject lateinit var progressSyncScheduler: ProgressSyncScheduler

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().setWorkerFactory(workerFactory).build()

    override fun onCreate() {
        super.onCreate()
        applicationScope.launch {
            bookCacheRepository.reconcile()
            // Flush progress recorded offline; no-op when nothing is dirty.
            progressSyncScheduler.schedule()
        }
    }
}
