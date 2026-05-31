package net.joker1007.bookwall.network

import coil3.ImageLoader
import net.joker1007.bookwall.data.server.OpdsServer

/** Supplies a Coil [ImageLoader] configured for a given OPDS server. */
fun interface ServerImageLoaderProvider {
    fun forServer(server: OpdsServer): ImageLoader?
}
