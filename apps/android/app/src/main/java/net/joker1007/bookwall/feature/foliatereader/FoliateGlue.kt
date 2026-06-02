package net.joker1007.bookwall.feature.foliatereader

import net.joker1007.bookwall.data.epub.EpubSettings
import net.joker1007.bookwall.data.epub.EpubTheme
import org.json.JSONArray

/**
 * Maps [EpubSettings] to the JSON the foliate glue's setStyles() expects
 * ({fontSize, theme, writingMode}). Pure so it can be unit-tested. foliate has
 * no scroll mode, so EpubSettings.scroll is intentionally ignored.
 */
fun foliateStylesJson(settings: EpubSettings): String {
    val theme = when (settings.theme) {
        EpubTheme.LIGHT -> "light"
        EpubTheme.SEPIA -> "sepia"
        EpubTheme.DARK -> "dark"
    }
    val writingMode = when (settings.verticalText) {
        true -> "vertical"
        false -> "horizontal"
        null -> "auto"
    }
    return """{"fontSize":${settings.fontSizePercent},"theme":"$theme","writingMode":"$writingMode"}"""
}

/** Flattens foliate's nested book.toc JSON into a depth-tagged list. */
fun parseToc(json: String): List<TocEntry> {
    val out = mutableListOf<TocEntry>()
    fun walk(array: JSONArray, depth: Int) {
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val label = item.optString("label").trim()
            val href = item.optString("href").ifEmpty { null }
            if (label.isNotEmpty()) out += TocEntry(label, href, depth)
            item.optJSONArray("subitems")?.let { walk(it, depth + 1) }
        }
    }
    runCatching { walk(JSONArray(json), 0) }
    return out
}
