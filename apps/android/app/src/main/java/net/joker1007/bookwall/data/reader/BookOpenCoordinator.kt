package net.joker1007.bookwall.data.reader

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import net.joker1007.bookwall.data.opds.OpdsEntry
import javax.inject.Inject
import javax.inject.Singleton

/** A request to open [book] in a reader, raised by a reader rolling over to the next book. */
data class OpenBookRequest(val serverId: Long, val book: OpdsEntry.Book)

/**
 * One-shot channel that lets either reader (the Compose image reader or the
 * separate foliate EPUB activity) ask the app host to open the next book. The
 * host owns the format branching (navigate vs. download + launch activity), so
 * the readers stay ignorant of navigation. A buffered channel keeps the request
 * if the host is paused (e.g. the EPUB activity is still on top) and delivers it
 * exactly once when collection resumes.
 */
@Singleton
class BookOpenCoordinator @Inject constructor() {
    private val channel = Channel<OpenBookRequest>(Channel.BUFFERED)
    val requests: Flow<OpenBookRequest> = channel.receiveAsFlow()

    fun request(serverId: Long, book: OpdsEntry.Book) {
        channel.trySend(OpenBookRequest(serverId, book))
    }
}
