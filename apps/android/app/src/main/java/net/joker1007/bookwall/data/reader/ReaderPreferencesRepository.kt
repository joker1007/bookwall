package net.joker1007.bookwall.data.reader

import kotlinx.coroutines.flow.Flow

/** App-wide reader preferences (tap-zone mapping). */
interface ReaderPreferencesRepository {
    val tapZoneConfig: Flow<TapZoneConfig>

    suspend fun setZoneAction(zone: TapZone, action: TapAction)
}
