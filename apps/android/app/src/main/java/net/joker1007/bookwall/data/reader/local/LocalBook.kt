package net.joker1007.bookwall.data.reader.local

import net.joker1007.bookwall.data.reader.PageSource
import java.io.Closeable
import java.io.File

/** A [PageSource] backed by an open local file handle that must be closed. */
interface ClosablePageSource : PageSource, Closeable

/** A local book file opened for reading, independent of any OPDS server. */
sealed interface LocalBook {
    /** Image-based book (CBZ/PDF): render through the shared reader UI. */
    class Images(val pageSource: ClosablePageSource) : LocalBook

    /** EPUB: hand the file to the foliate-js reader activity. */
    class Epub(val file: File) : LocalBook
}
