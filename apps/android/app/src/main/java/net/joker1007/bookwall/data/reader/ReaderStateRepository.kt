package net.joker1007.bookwall.data.reader

interface ReaderStateRepository {
    /** Returns the saved reader state for a book, or null if none exists yet. */
    suspend fun load(serverId: Long, bookId: Long): ReaderState?

    suspend fun save(serverId: Long, bookId: Long, state: ReaderState)
}
