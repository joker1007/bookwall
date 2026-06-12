package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory queue of the catalog book list a reader was opened from, so the
 * reader can roll over to the next book once the current one ends. Replaced each
 * time a book is opened from the catalog; lost on process death (acceptable: the
 * "next book" affordance simply disappears, the reader still works standalone).
 */
@Singleton
class ReadingQueueHolder @Inject constructor() {
    private var serverId: Long = 0L
    private var books: List<OpdsEntry.Book> = emptyList()

    fun set(serverId: Long, books: List<OpdsEntry.Book>) {
        this.serverId = serverId
        this.books = books
    }

    /** The book following [bookId] in the queue, or null at the end / when absent. */
    fun nextAfter(serverId: Long, bookId: Long): OpdsEntry.Book? {
        if (serverId != this.serverId) return null
        val index = books.indexOfFirst { it.numericId == bookId }
        if (index < 0) return null
        return books.getOrNull(index + 1)
    }
}
