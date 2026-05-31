package net.joker1007.bookwall.data.opds

import java.io.InputStream

/** Parses an OPDS feed from a raw byte stream. */
interface FeedParser {
    fun parse(input: InputStream): OpdsFeed
}
