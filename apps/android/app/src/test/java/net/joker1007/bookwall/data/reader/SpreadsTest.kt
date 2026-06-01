package net.joker1007.bookwall.data.reader

import org.junit.Assert.assertEquals
import org.junit.Test

class SpreadsTest {

    @Test
    fun `single mode yields one page per slot`() {
        val slots = buildSpreads(pageCount = 3, spreadEnabled = false, offset = 0)
        assertEquals(listOf(listOf(0), listOf(1), listOf(2)), slots)
    }

    @Test
    fun `spread mode pairs pages`() {
        val slots = buildSpreads(pageCount = 6, spreadEnabled = true, offset = 0)
        assertEquals(listOf(listOf(0, 1), listOf(2, 3), listOf(4, 5)), slots)
    }

    @Test
    fun `spread mode leaves a trailing lone page for odd counts`() {
        val slots = buildSpreads(pageCount = 5, spreadEnabled = true, offset = 0)
        assertEquals(listOf(listOf(0, 1), listOf(2, 3), listOf(4)), slots)
    }

    @Test
    fun `offset shifts pairing by one page`() {
        val slots = buildSpreads(pageCount = 5, spreadEnabled = true, offset = 1)
        assertEquals(listOf(listOf(0), listOf(1, 2), listOf(3, 4)), slots)
    }

    @Test
    fun `slotIndexForPage finds the containing slot`() {
        val slots = buildSpreads(pageCount = 6, spreadEnabled = true, offset = 0)
        assertEquals(0, slotIndexForPage(slots, 0))
        assertEquals(0, slotIndexForPage(slots, 1))
        assertEquals(2, slotIndexForPage(slots, 5))
    }

    @Test
    fun `empty when no pages`() {
        assertEquals(emptyList<List<Int>>(), buildSpreads(0, spreadEnabled = true, offset = 0))
    }
}
