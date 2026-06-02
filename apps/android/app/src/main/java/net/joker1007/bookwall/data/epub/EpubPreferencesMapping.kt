package net.joker1007.bookwall.data.epub

import org.readium.r2.navigator.epub.EpubPreferences
import org.readium.r2.navigator.preferences.Theme

/** Maps app [EpubSettings] to Readium [EpubPreferences]. */
fun EpubSettings.toEpubPreferences(): EpubPreferences = EpubPreferences(
    theme = when (theme) {
        EpubTheme.LIGHT -> Theme.LIGHT
        EpubTheme.SEPIA -> Theme.SEPIA
        EpubTheme.DARK -> Theme.DARK
    },
    fontSize = fontSizePercent / 100.0,
    verticalText = verticalText,
    scroll = scroll,
)
