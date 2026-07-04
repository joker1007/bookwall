package net.joker1007.bookwall.data.reader

interface ReaderStateRepository {
    /** Returns the saved reader state for a book, or null if none exists yet. */
    suspend fun load(serverId: Long, bookId: Long): ReaderState?

    /** Saves the state and marks it dirty (pending server sync). */
    suspend fun save(serverId: Long, bookId: Long, state: ReaderState)

    /** Clears the dirty mark after a successful push, unless a newer save landed. */
    suspend fun markSynced(serverId: Long, bookId: Long)
}
