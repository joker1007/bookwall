package net.joker1007.bookwall.data.reader

/**
 * Supplies the pages of an image-based book to the reader. Decouples the reader
 * from where pages come from (OPDS PSE streaming today; local files later).
 */
interface PageSource {
    val pageCount: Int

    /** A Coil model (e.g. a resolved URL) for page [index] (0-based), or null if out of range. */
    fun pageModel(index: Int): Any?
}
