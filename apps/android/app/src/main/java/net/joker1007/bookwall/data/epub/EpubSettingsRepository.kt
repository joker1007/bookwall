package net.joker1007.bookwall.data.epub

import kotlinx.coroutines.flow.Flow

interface EpubSettingsRepository {
    val settings: Flow<EpubSettings>

    suspend fun setTheme(theme: EpubTheme)

    suspend fun setFontSizePercent(percent: Int)

    suspend fun setVerticalText(enabled: Boolean?)

    suspend fun setScroll(enabled: Boolean)
}
