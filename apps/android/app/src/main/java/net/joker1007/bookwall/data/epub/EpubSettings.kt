package net.joker1007.bookwall.data.epub

enum class EpubTheme { LIGHT, SEPIA, DARK }

/** App-wide EPUB reader presentation settings. */
data class EpubSettings(
    val theme: EpubTheme = EpubTheme.LIGHT,
    val fontSizePercent: Int = 100,
    /** null = let Readium auto-detect from the publication (e.g. vertical CJK). */
    val verticalText: Boolean? = null,
    val scroll: Boolean = false,
)
