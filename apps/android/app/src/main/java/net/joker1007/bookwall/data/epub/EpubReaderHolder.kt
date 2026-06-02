package net.joker1007.bookwall.data.epub

import org.readium.r2.navigator.epub.EpubNavigatorFactory
import org.readium.r2.shared.publication.Publication
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.inject.Inject
import javax.inject.Singleton

/** An opened EPUB ready to be displayed by the reader activity. */
class EpubSession(
    val publication: Publication,
    val navigatorFactory: EpubNavigatorFactory,
    val serverId: Long,
    val bookId: Long,
    val title: String,
)

/**
 * Holds opened [EpubSession]s in memory so a freshly-opened publication can be
 * handed to [net.joker1007.bookwall.feature.epubreader.EpubReaderActivity] by id
 * (Readium needs the navigator factory available at Activity.onCreate time).
 */
@Singleton
class EpubReaderHolder @Inject constructor() {
    private val sessions = ConcurrentHashMap<Long, EpubSession>()
    private val counter = AtomicLong(0)

    fun put(session: EpubSession): Long {
        val id = counter.incrementAndGet()
        sessions[id] = session
        return id
    }

    fun get(id: Long): EpubSession? = sessions[id]

    fun remove(id: Long) {
        sessions.remove(id)?.publication?.close()
    }
}
