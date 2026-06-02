package net.joker1007.bookwall.data.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TapActionTest {

    private val singleSlots = buildSpreads(pageCount = 10, spreadEnabled = false, offset = 0)
    private val spreadSlots = buildSpreads(pageCount = 10, spreadEnabled = true, offset = 0)

    @Test
    fun `default config maps zones to previous, menu, next`() {
        val config = TapZoneConfig()
        assertEquals(TapAction.PREVIOUS, config.actionFor(TapZone.LEFT))
        assertEquals(TapAction.TOGGLE_MENU, config.actionFor(TapZone.CENTER))
        assertEquals(TapAction.NEXT, config.actionFor(TapZone.RIGHT))
    }

    @Test
    fun `with replaces a single zone and center stays menu`() {
        val config = TapZoneConfig().with(TapZone.LEFT, TapAction.NEXT_CONTINUOUS)
        assertEquals(TapAction.NEXT_CONTINUOUS, config.left)
        assertEquals(TapAction.TOGGLE_MENU, config.actionFor(TapZone.CENTER))
    }

    @Test
    fun `center is not customizable`() {
        val config = TapZoneConfig().with(TapZone.CENTER, TapAction.NEXT)
        assertEquals(TapAction.TOGGLE_MENU, config.actionFor(TapZone.CENTER))
    }

    @Test
    fun `rtl flip swaps left and right but keeps center`() {
        assertEquals(TapZone.RIGHT, TapZone.LEFT.flippedForRtl())
        assertEquals(TapZone.LEFT, TapZone.RIGHT.flippedForRtl())
        assertEquals(TapZone.CENTER, TapZone.CENTER.flippedForRtl())
    }

    @Test
    fun `next advances by one slot in spread mode`() {
        // current page 0 -> slot 0 [0,1]; NEXT -> slot 1 [2,3] first page = 2
        assertEquals(2, tapTargetPage(TapAction.NEXT, spreadSlots, currentPage = 0))
    }

    @Test
    fun `next single advances by one page even in spread mode`() {
        assertEquals(1, tapTargetPage(TapAction.NEXT_SINGLE, spreadSlots, currentPage = 0))
    }

    @Test
    fun `continuous jumps by the step`() {
        assertEquals(5, tapTargetPage(TapAction.NEXT_CONTINUOUS, singleSlots, currentPage = 0, continuousStep = 5))
        assertEquals(-3, tapTargetPage(TapAction.PREVIOUS_CONTINUOUS, singleSlots, currentPage = 2, continuousStep = 5))
    }

    @Test
    fun `menu and none do not move pages`() {
        assertNull(tapTargetPage(TapAction.TOGGLE_MENU, singleSlots, currentPage = 3))
        assertNull(tapTargetPage(TapAction.NONE, singleSlots, currentPage = 3))
    }
}
