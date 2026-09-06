package net.joker1007.bookwall.data.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpreadModeTest {
    @Test
    fun `OFF and ON ignore orientation`() {
        assertFalse(SpreadMode.OFF.isEnabled(landscape = true))
        assertFalse(SpreadMode.OFF.isEnabled(landscape = false))
        assertTrue(SpreadMode.ON.isEnabled(landscape = true))
        assertTrue(SpreadMode.ON.isEnabled(landscape = false))
    }

    @Test
    fun `AUTO follows orientation`() {
        assertTrue(SpreadMode.AUTO.isEnabled(landscape = true))
        assertFalse(SpreadMode.AUTO.isEnabled(landscape = false))
    }

    @Test
    fun `fromStorage falls back to OFF for unknown values`() {
        assertEquals(SpreadMode.AUTO, SpreadMode.fromStorage("AUTO"))
        assertEquals(SpreadMode.OFF, SpreadMode.fromStorage(null))
        assertEquals(SpreadMode.OFF, SpreadMode.fromStorage("bogus"))
    }
}
