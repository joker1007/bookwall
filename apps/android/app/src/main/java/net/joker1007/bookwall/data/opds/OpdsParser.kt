package net.joker1007.bookwall.data.opds

import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import java.io.InputStream
import javax.inject.Inject

/**
 * Parses Bookwall OPDS Atom feeds. Namespace processing is disabled, so
 * prefixed names emitted by the server (pse:, dc:, opds:, thr:) are matched
 * verbatim. The core [parse] takes an [XmlPullParser] so it is unit-testable
 * off-device.
 */
class OpdsParser @Inject constructor() : FeedParser {

    override fun parse(input: InputStream): OpdsFeed {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(input, null)
        return parse(parser)
    }

    fun parse(parser: XmlPullParser): OpdsFeed {
        var title = ""
        var id = ""
        var selfHref: String? = null
        var progressSyncTemplate: String? = null
        val entries = mutableListOf<OpdsEntry>()
        val facets = mutableListOf<OpdsFacet>()

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG) {
                when (parser.name) {
                    "entry" -> parseEntry(parser)?.let { entries += it }
                    "title" -> if (title.isEmpty()) title = parser.nextText().trim()
                    "id" -> if (id.isEmpty()) id = parser.nextText().trim()
                    "link" -> {
                        val rel = parser.attr("rel")
                        val href = parser.attr("href")
                        when {
                            rel == "self" -> selfHref = href
                            rel == FACET_REL && href != null -> facets += parser.toFacet(href)
                            rel == PROGRESS_SYNC_REL && href != null -> progressSyncTemplate = href
                        }
                    }
                }
            }
            event = parser.next()
        }
        return OpdsFeed(
            title = title,
            id = id,
            selfHref = selfHref,
            entries = entries,
            facets = facets,
            progressSyncTemplate = progressSyncTemplate,
        )
    }

    private fun parseEntry(parser: XmlPullParser): OpdsEntry? {
        var title = ""
        var id = ""
        var summary: String? = null
        var language: String? = null
        var format: String? = null
        val authors = mutableListOf<String>()
        val tags = mutableListOf<String>()
        var acquisitionHref: String? = null
        var acquisitionType: String? = null
        var imageHref: String? = null
        var thumbnailHref: String? = null
        var pse: PseInfo? = null
        var navHref: String? = null
        var navRel: String? = null

        var event = parser.next()
        while (!(event == XmlPullParser.END_TAG && parser.name == "entry")) {
            if (event == XmlPullParser.START_TAG) {
                when (parser.name) {
                    "title" -> title = parser.nextText().trim()
                    "id" -> id = parser.nextText().trim()
                    "content" -> summary = parser.nextText().trim().ifEmpty { null }
                    "dc:language" -> language = parser.nextText().trim().ifEmpty { null }
                    "dc:format" -> format = parser.nextText().trim().ifEmpty { null }
                    "author" -> parseAuthorName(parser)?.let { authors += it }
                    "category" -> parser.attr("term")?.let { tags += it }
                    "link" -> {
                        val rel = parser.attr("rel")
                        val href = parser.attr("href")
                        when (rel) {
                            ACQUISITION_REL -> {
                                acquisitionHref = href
                                acquisitionType = parser.attr("type")
                            }
                            IMAGE_REL -> imageHref = href
                            THUMB_REL -> thumbnailHref = href
                            else -> if (navHref == null && href != null) {
                                navHref = href
                                navRel = rel
                            }
                        }
                    }
                    "pse:link" -> pse = parser.toPse()
                }
            }
            event = parser.next()
        }

        val isBook = acquisitionHref != null || pse != null
        return when {
            isBook -> OpdsEntry.Book(
                title = title,
                id = id,
                authors = authors,
                tags = tags,
                summary = summary,
                language = language,
                format = format,
                acquisitionHref = acquisitionHref,
                acquisitionType = acquisitionType,
                imageHref = imageHref,
                thumbnailHref = thumbnailHref,
                pse = pse,
            )
            navHref != null -> OpdsEntry.Navigation(
                title = title,
                id = id,
                href = navHref,
                rel = navRel,
                summary = summary,
            )
            else -> null
        }
    }

    private fun parseAuthorName(parser: XmlPullParser): String? {
        var name: String? = null
        var event = parser.next()
        while (!(event == XmlPullParser.END_TAG && parser.name == "author")) {
            if (event == XmlPullParser.START_TAG && parser.name == "name") {
                name = parser.nextText().trim().ifEmpty { null }
            }
            event = parser.next()
        }
        return name
    }

    private fun XmlPullParser.attr(name: String): String? = getAttributeValue(null, name)

    private fun XmlPullParser.toFacet(href: String): OpdsFacet = OpdsFacet(
        href = href,
        title = attr("title"),
        group = attr("opds:facetGroup"),
        count = attr("thr:count")?.toIntOrNull(),
        active = attr("opds:activeFacet") == "true",
    )

    private fun XmlPullParser.toPse(): PseInfo? {
        val href = attr("href") ?: return null
        return PseInfo(
            streamHrefTemplate = href,
            pageCount = attr("pse:count")?.toIntOrNull() ?: 0,
            lastRead = attr("pse:lastRead")?.toIntOrNull(),
            lastReadDate = attr("pse:lastReadDate"),
        )
    }

    companion object {
        const val ACQUISITION_REL = "http://opds-spec.org/acquisition"
        const val IMAGE_REL = "http://opds-spec.org/image"
        const val THUMB_REL = "http://opds-spec.org/image/thumbnail"
        const val PSE_STREAM_REL = "http://vaemendis.net/opds-pse/stream"
        const val FACET_REL = "http://opds-spec.org/facet"
        const val PROGRESS_SYNC_REL = "https://bookwall.joker1007.net/rel/progress-sync"
        const val PSE_PAGE_TOKEN = "{pageNumber}"
        const val BOOK_ID_TOKEN = "{bookId}"
    }
}
