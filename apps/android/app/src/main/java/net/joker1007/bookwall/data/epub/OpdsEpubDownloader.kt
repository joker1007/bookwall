package net.joker1007.bookwall.data.epub

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.data.opds.resolveOpdsHref
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.di.IoDispatcher
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.Request
import java.io.File
import java.io.IOException
import javax.inject.Inject

/** Downloads an EPUB to the cache directory using the server's credentials. */
class OpdsEpubDownloader @Inject constructor(
    @ApplicationContext private val context: Context,
    private val clientFactory: OkHttpClientFactory,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : EpubDownloader {
    override suspend fun download(server: OpdsServer, book: OpdsEntry.Book): File = withContext(ioDispatcher) {
        val href = book.acquisitionHref ?: throw IOException("No acquisition link")
        val url = resolveOpdsHref(server.baseUrl, href) ?: throw IOException("Bad acquisition URL")
        val dir = File(context.cacheDir, "epubs").apply { mkdirs() }
        val file = File(dir, "${server.id}_${book.numericId ?: book.id.hashCode()}.epub")

        clientFactory.forServer(server).newCall(Request.Builder().url(url).build()).execute().use { response ->
            if (!response.isSuccessful) throw IOException("Download failed: HTTP ${response.code}")
            val body = response.body
            file.outputStream().use { out -> body.byteStream().copyTo(out) }
        }
        file
    }
}
