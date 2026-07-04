package net.joker1007.bookwall.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.cache.CacheSettings
import net.joker1007.bookwall.data.cache.CacheSettingsRepository
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val cacheSettingsRepository: CacheSettingsRepository,
    private val bookCacheRepository: BookCacheRepository,
) : ViewModel() {

    val settings: StateFlow<CacheSettings> = cacheSettingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CacheSettings())

    val usageBytes: StateFlow<Long> = bookCacheRepository.observeCompletedBytes()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0L)

    fun setWifiOnly(value: Boolean) {
        viewModelScope.launch {
            cacheSettingsRepository.setWifiOnly(value)
            // Enqueued work keeps its constraints, so re-register the drainer.
            bookCacheRepository.rescheduleDownloads()
        }
    }

    fun setAutoCacheOnRead(value: Boolean) {
        viewModelScope.launch { cacheSettingsRepository.setAutoCacheOnRead(value) }
    }

    fun setMaxCacheBytes(value: Long) {
        viewModelScope.launch {
            cacheSettingsRepository.setMaxCacheBytes(value)
            bookCacheRepository.enforceLimit()
        }
    }

    fun deleteAllCache() {
        viewModelScope.launch { bookCacheRepository.deleteAll() }
    }
}
