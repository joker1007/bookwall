package net.joker1007.bookwall.data

import net.joker1007.bookwall.data.reader.ReaderState
import net.joker1007.bookwall.data.reader.ReaderStateRepository

/** In-memory [ReaderStateRepository] for unit tests. */
class FakeReaderStateRepository : ReaderStateRepository {
    val saved = mutableMapOf<Pair<Long, Long>, ReaderState>()

    /** Pre-existing state returned by [load] when nothing has been saved yet. */
    var preset: ReaderState? = null

    override suspend fun load(serverId: Long, bookId: Long): ReaderState? =
        saved[serverId to bookId] ?: preset

    override suspend fun save(serverId: Long, bookId: Long, state: ReaderState) {
        saved[serverId to bookId] = state
    }
}
