package net.joker1007.bookwall.data.epub

enum class EpubTheme { LIGHT, SEPIA, DARK }

/** App-wide EPUB reader presentation settings. */
data class EpubSettings(
    val theme: EpubTheme = EpubTheme.LIGHT,
    val fontSizePercent: Int = 100,
    val verticalText: Boolean = false,
    val scroll: Boolean = false,
)
