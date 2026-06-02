package net.joker1007.bookwall.data.epub

import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.server.OpdsServer
import java.io.File

/** Downloads an EPUB to local storage using the server's credentials. */
fun interface EpubDownloader {
    suspend fun download(server: OpdsServer, book: OpdsEntry.Book): File
}
