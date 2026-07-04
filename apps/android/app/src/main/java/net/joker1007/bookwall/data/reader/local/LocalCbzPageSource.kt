package net.joker1007.bookwall.data.reader.local

import java.io.File
import java.io.InputStream
import java.util.zip.ZipFile

/** A page of an open CBZ; resolved by [CbzPageFetcher] via the owning source. */
data class CbzPage(val source: LocalCbzPageSource, val index: Int)

/**
 * Serves CBZ pages straight out of the archive (no extraction). Page order is
 * the lowercased entry-name lexicographic sort — the same rule the server's
 * CBZ parser uses, so page numbers stay interchangeable with PSE progress.
 */
class LocalCbzPageSource private constructor(
    private val zip: ZipFile,
    private val entryNames: List<String>,
    val filePath: String,
) : ClosablePageSource {

    override val pageCount: Int = entryNames.size

    override fun pageModel(index: Int): Any? =
        if (index in entryNames.indices) CbzPage(this, index) else null

    fun cacheKey(index: Int): String = "cbz:$filePath:${entryNames[index]}"

    /** [ZipFile.getInputStream] is internally synchronized, so concurrent reads are safe. */
    fun openPage(index: Int): InputStream {
        val entry = zip.getEntry(entryNames[index]) ?: error("Missing CBZ entry ${entryNames[index]}")
        return zip.getInputStream(entry)
    }

    override fun close() = zip.close()

    companion object {
        private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp")

        fun open(file: File): LocalCbzPageSource {
            val zip = ZipFile(file)
            val names = zip.entries().asSequence()
                .filter { !it.isDirectory }
                .map { it.name }
                .filter { it.substringAfterLast('.', "").lowercase() in IMAGE_EXTENSIONS }
                .sortedBy { it.lowercase() }
                .toList()
            return LocalCbzPageSource(zip, names, file.absolutePath)
        }
    }
}
