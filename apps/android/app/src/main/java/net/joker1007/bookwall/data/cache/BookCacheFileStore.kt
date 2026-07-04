package net.joker1007.bookwall.data.cache

import java.io.File

/**
 * File layout for cached books. Files live under filesDir (not cacheDir) so
 * the OS never evicts them behind our back; total size is bounded by the
 * app's own LRU limit instead.
 */
class BookCacheFileStore(val root: File) {

    fun bookFileName(serverId: Long, bookId: Long, mime: String?): String =
        "$serverId/$bookId.${extensionFor(mime)}"

    fun thumbFileName(serverId: Long, bookId: Long): String = "thumbs/${serverId}_$bookId.jpg"

    /** Resolves a relative name from the DB row, creating parent directories. */
    fun fileFor(relativeName: String): File =
        File(root, relativeName).apply { parentFile?.mkdirs() }

    fun partFileFor(relativeName: String): File = fileFor("$relativeName.part")

    companion object {
        fun extensionFor(mime: String?): String = when (mime) {
            "application/x-cbz", "application/vnd.comicbook+zip" -> "cbz"
            "application/epub+zip" -> "epub"
            "application/pdf" -> "pdf"
            else -> "bin"
        }
    }
}
