package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.opds.FeedResult
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.OpdsRepository
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.opds.resolveOpdsHref
import net.joker1007.bookwall.data.server.OpdsServer
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Resolves the "next volume" for a reader by fetching the book's series
 * sub-catalog (advertised as an atom rel="related" link on the book entry) and
 * picking the entry after the current book. The server returns the series in
 * volume order, matching the web reader's Book#next_in_series, so the reader
 * rolls over to the same next volume the web reader would.
 *
 * Returns null when the book has no series link, the server is a non-Bookwall
 * feed that omits it, the current book is the last volume, or the fetch fails —
 * in every case the "next book" affordance simply does not appear.
 */
@Singleton
class NextInSeriesResolver @Inject constructor(
    private val opdsRepository: OpdsRepository,
) {
    suspend fun resolve(server: OpdsServer, seriesHref: String?, currentBookId: Long): OpdsEntry.Book? {
        if (seriesHref.isNullOrEmpty()) return null
        val url = resolveOpdsHref(server.baseUrl, seriesHref) ?: return null
        val feed = (opdsRepository.fetchFeed(server, url) as? FeedResult.Success)?.feed ?: return null
        val books = feed.entries.filterIsInstance<OpdsEntry.Book>()
        val index = books.indexOfFirst { it.numericId == currentBookId }
        if (index < 0) return null
        return books.getOrNull(index + 1)
    }
}
