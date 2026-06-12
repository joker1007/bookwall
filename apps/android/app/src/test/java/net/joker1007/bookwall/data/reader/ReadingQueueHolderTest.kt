package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.PseInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReadingQueueHolderTest {

    private fun book(id: Long) = OpdsEntry.Book(
        title = "Vol $id",
        id = "urn:bookwall:book:$id",
        pse = PseInfo(streamHrefTemplate = "/p/{pageNumber}", pageCount = 1),
    )

    private val holder = ReadingQueueHolder().apply {
        set(serverId = 1L, books = listOf(book(10), book(20), book(30)))
    }

    @Test
    fun `returns the book following the given id`() {
        assertEquals(20L, holder.nextAfter(1L, 10L)?.id?.substringAfterLast(':')?.toLong())
        assertEquals(30L, holder.nextAfter(1L, 20L)?.id?.substringAfterLast(':')?.toLong())
    }

    @Test
    fun `returns null at the end of the queue`() {
        assertNull(holder.nextAfter(1L, 30L))
    }

    @Test
    fun `returns null when the book is not in the queue`() {
        assertNull(holder.nextAfter(1L, 999L))
    }

    @Test
    fun `returns null for a different server`() {
        assertNull(holder.nextAfter(2L, 10L))
    }

    @Test
    fun `set replaces the previous queue`() {
        holder.set(serverId = 1L, books = listOf(book(40), book(50)))
        assertEquals(50L, holder.nextAfter(1L, 40L)?.id?.substringAfterLast(':')?.toLong())
        assertNull(holder.nextAfter(1L, 10L))
    }
}
