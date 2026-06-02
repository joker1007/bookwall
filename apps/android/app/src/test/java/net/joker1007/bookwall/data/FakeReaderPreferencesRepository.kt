package net.joker1007.bookwall.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import net.joker1007.bookwall.data.reader.ReaderPreferencesRepository
import net.joker1007.bookwall.data.reader.TapAction
import net.joker1007.bookwall.data.reader.TapZone
import net.joker1007.bookwall.data.reader.TapZoneConfig

/** In-memory [ReaderPreferencesRepository] for unit tests. */
class FakeReaderPreferencesRepository : ReaderPreferencesRepository {
    private val config = MutableStateFlow(TapZoneConfig())

    override val tapZoneConfig: Flow<TapZoneConfig> = config

    override suspend fun setZoneAction(zone: TapZone, action: TapAction) {
        config.value = config.value.with(zone, action)
    }

    fun current(): TapZoneConfig = config.value
}
