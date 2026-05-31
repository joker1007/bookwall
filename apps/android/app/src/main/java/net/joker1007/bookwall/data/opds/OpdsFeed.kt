package net.joker1007.bookwall.data.opds

/** A parsed OPDS feed (either a navigation or an acquisition feed). */
data class OpdsFeed(
    val title: String,
    val id: String,
    val selfHref: String? = null,
    val entries: List<OpdsEntry> = emptyList(),
    val facets: List<OpdsFacet> = emptyList(),
) {
    val isAcquisition: Boolean get() = entries.any { it is OpdsEntry.Book }
}

sealed interface OpdsEntry {
    val title: String
    val id: String

    /** A link to another feed (sub-catalog). */
    data class Navigation(
        override val title: String,
        override val id: String,
        val href: String,
        val rel: String? = null,
        val summary: String? = null,
    ) : OpdsEntry

    /** A publication entry with acquisition / cover / page-streaming links. */
    data class Book(
        override val title: String,
        override val id: String,
        val authors: List<String> = emptyList(),
        val tags: List<String> = emptyList(),
        val summary: String? = null,
        val language: String? = null,
        val format: String? = null,
        val acquisitionHref: String? = null,
        val acquisitionType: String? = null,
        val imageHref: String? = null,
        val thumbnailHref: String? = null,
        val pse: PseInfo? = null,
    ) : OpdsEntry
}

/** OPDS Page Streaming Extension info for image-based books (CBZ/PDF/image_dir). */
data class PseInfo(
    /** href containing the literal "{pageNumber}" token. */
    val streamHrefTemplate: String,
    val pageCount: Int,
    /** 1-based last read page per the PSE spec, if the server reported progress. */
    val lastRead: Int? = null,
    val lastReadDate: String? = null,
)

data class OpdsFacet(
    val href: String,
    val title: String? = null,
    val group: String? = null,
    val count: Int? = null,
    val active: Boolean = false,
)
