package net.joker1007.bookwall.feature.foliatereader

import net.joker1007.bookwall.data.epub.EpubSettings
import net.joker1007.bookwall.data.epub.EpubTheme
import org.junit.Assert.assertEquals
import org.junit.Test

class FoliateGlueTest {

    @Test
    fun `maps defaults to light auto 100`() {
        assertEquals(
            """{"fontSize":100,"theme":"light","writingMode":"auto"}""",
            foliateStylesJson(EpubSettings()),
        )
    }

    @Test
    fun `maps dark theme and font size`() {
        assertEquals(
            """{"fontSize":140,"theme":"dark","writingMode":"auto"}""",
            foliateStylesJson(EpubSettings(theme = EpubTheme.DARK, fontSizePercent = 140)),
        )
    }

    @Test
    fun `forced vertical maps to vertical writing mode`() {
        assertEquals(
            """{"fontSize":100,"theme":"sepia","writingMode":"vertical"}""",
            foliateStylesJson(EpubSettings(theme = EpubTheme.SEPIA, verticalText = true)),
        )
    }

    @Test
    fun `explicit horizontal maps to horizontal`() {
        assertEquals(
            """{"fontSize":100,"theme":"light","writingMode":"horizontal"}""",
            foliateStylesJson(EpubSettings(verticalText = false)),
        )
    }
}
