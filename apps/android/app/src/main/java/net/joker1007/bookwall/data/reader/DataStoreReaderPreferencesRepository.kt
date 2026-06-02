package net.joker1007.bookwall.data.reader

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class DataStoreReaderPreferencesRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : ReaderPreferencesRepository {

    override val tapZoneConfig: Flow<TapZoneConfig> = dataStore.data.map { prefs ->
        TapZoneConfig(
            left = prefs[keyFor(TapZone.LEFT)].toActionOr(TapAction.PREVIOUS),
            right = prefs[keyFor(TapZone.RIGHT)].toActionOr(TapAction.NEXT),
        )
    }

    override suspend fun setZoneAction(zone: TapZone, action: TapAction) {
        dataStore.edit { prefs -> prefs[keyFor(zone)] = action.name }
    }

    private fun keyFor(zone: TapZone) = stringPreferencesKey("tap_zone_${zone.name.lowercase()}")

    private fun String?.toActionOr(default: TapAction): TapAction =
        this?.let { runCatching { TapAction.valueOf(it) }.getOrNull() } ?: default
}
