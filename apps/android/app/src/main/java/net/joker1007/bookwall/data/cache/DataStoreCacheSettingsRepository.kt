package net.joker1007.bookwall.data.cache

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class DataStoreCacheSettingsRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : CacheSettingsRepository {

    override val settings: Flow<CacheSettings> = dataStore.data.map { prefs ->
        CacheSettings(
            wifiOnly = prefs[WIFI_ONLY] ?: true,
            autoCacheOnRead = prefs[AUTO_CACHE_ON_READ] ?: true,
            maxCacheBytes = prefs[MAX_CACHE_BYTES] ?: CacheSettings.DEFAULT_MAX_CACHE_BYTES,
        )
    }

    override suspend fun setWifiOnly(value: Boolean) {
        dataStore.edit { prefs -> prefs[WIFI_ONLY] = value }
    }

    override suspend fun setAutoCacheOnRead(value: Boolean) {
        dataStore.edit { prefs -> prefs[AUTO_CACHE_ON_READ] = value }
    }

    override suspend fun setMaxCacheBytes(value: Long) {
        dataStore.edit { prefs -> prefs[MAX_CACHE_BYTES] = value }
    }

    private companion object {
        val WIFI_ONLY = booleanPreferencesKey("cache_wifi_only")
        val AUTO_CACHE_ON_READ = booleanPreferencesKey("cache_auto_on_read")
        val MAX_CACHE_BYTES = longPreferencesKey("cache_max_bytes")
    }
}
