package net.joker1007.bookwall.data.epub

import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.server.OpdsServer

/** Opens an EPUB book into a displayable [EpubSession]. */
fun interface EpubOpener {
    suspend fun open(server: OpdsServer, book: OpdsEntry.Book): Result<EpubSession>
}
