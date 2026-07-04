package net.joker1007.bookwall.data.reader.local

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.di.IoDispatcher
import java.io.File
import java.util.zip.ZipFile
import javax.inject.Inject

/**
 * Opens a local book file (a cached download today, direct device storage
 * later) as a [LocalBook]. Format detection prefers the MIME hint, then the
 * file extension, then content sniffing.
 */
class LocalBookSourceFactory @Inject constructor(
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    suspend fun open(file: File, mimeHint: String? = null): LocalBook = withContext(ioDispatcher) {
        when (detectFormat(file, mimeHint)) {
            Format.EPUB -> LocalBook.Epub(file)
            Format.PDF -> LocalBook.Images(LocalPdfPageSource.open(file))
            Format.CBZ -> LocalBook.Images(LocalCbzPageSource.open(file))
        }
    }

    private enum class Format { CBZ, PDF, EPUB }

    private fun detectFormat(file: File, mimeHint: String?): Format {
        when (mimeHint) {
            "application/epub+zip" -> return Format.EPUB
            "application/pdf" -> return Format.PDF
            "application/x-cbz", "application/vnd.comicbook+zip" -> return Format.CBZ
        }
        when (file.extension.lowercase()) {
            "epub" -> return Format.EPUB
            "pdf" -> return Format.PDF
            "cbz" -> return Format.CBZ
        }
        return sniffFormat(file)
    }

    private fun sniffFormat(file: File): Format {
        val header = ByteArray(4)
        file.inputStream().use { it.read(header) }
        return when {
            header.startsWith(PDF_MAGIC) -> Format.PDF
            header.startsWith(ZIP_MAGIC) -> if (isEpubArchive(file)) Format.EPUB else Format.CBZ
            else -> Format.CBZ
        }
    }

    /** EPUB is a ZIP whose "mimetype" entry declares application/epub+zip. */
    private fun isEpubArchive(file: File): Boolean = runCatching {
        ZipFile(file).use { zip ->
            val entry = zip.getEntry("mimetype") ?: return false
            zip.getInputStream(entry).use { input ->
                input.readBytes().decodeToString().trim() == "application/epub+zip"
            }
        }
    }.getOrDefault(false)

    private fun ByteArray.startsWith(prefix: ByteArray): Boolean =
        size >= prefix.size && prefix.indices.all { this[it] == prefix[it] }

    private companion object {
        val PDF_MAGIC = "%PDF".toByteArray()
        val ZIP_MAGIC = byteArrayOf(0x50, 0x4B, 0x03, 0x04)
    }
}
