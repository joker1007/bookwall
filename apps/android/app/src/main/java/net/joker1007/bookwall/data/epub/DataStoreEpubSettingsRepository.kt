package net.joker1007.bookwall.data.epub

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class DataStoreEpubSettingsRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : EpubSettingsRepository {

    private val themeKey = stringPreferencesKey("epub_theme")
    private val fontSizeKey = intPreferencesKey("epub_font_size")
    private val verticalKey = booleanPreferencesKey("epub_vertical")
    private val scrollKey = booleanPreferencesKey("epub_scroll")

    override val settings: Flow<EpubSettings> = dataStore.data.map { prefs ->
        EpubSettings(
            theme = prefs[themeKey]?.let { runCatching { EpubTheme.valueOf(it) }.getOrNull() } ?: EpubTheme.LIGHT,
            fontSizePercent = prefs[fontSizeKey] ?: 100,
            verticalText = prefs[verticalKey],
            scroll = prefs[scrollKey] ?: false,
        )
    }

    override suspend fun setTheme(theme: EpubTheme) {
        dataStore.edit { it[themeKey] = theme.name }
    }

    override suspend fun setFontSizePercent(percent: Int) {
        dataStore.edit { it[fontSizeKey] = percent.coerceIn(50, 250) }
    }

    override suspend fun setVerticalText(enabled: Boolean?) {
        dataStore.edit {
            if (enabled == null) it.remove(verticalKey) else it[verticalKey] = enabled
        }
    }

    override suspend fun setScroll(enabled: Boolean) {
        dataStore.edit { it[scrollKey] = enabled }
    }
}
