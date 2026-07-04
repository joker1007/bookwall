package net.joker1007.bookwall.data.cache

import kotlinx.coroutines.flow.Flow

data class CacheSettings(
    /** Restrict background downloads to unmetered (Wi-Fi) networks. */
    val wifiOnly: Boolean = true,
    /** Automatically cache a book when it is opened in a reader. */
    val autoCacheOnRead: Boolean = true,
    /** Total cache size limit in bytes; 0 = unlimited. */
    val maxCacheBytes: Long = DEFAULT_MAX_CACHE_BYTES,
) {
    companion object {
        const val DEFAULT_MAX_CACHE_BYTES = 10L * 1024 * 1024 * 1024
    }
}

interface CacheSettingsRepository {
    val settings: Flow<CacheSettings>

    suspend fun setWifiOnly(value: Boolean)

    suspend fun setAutoCacheOnRead(value: Boolean)

    suspend fun setMaxCacheBytes(value: Long)
}
