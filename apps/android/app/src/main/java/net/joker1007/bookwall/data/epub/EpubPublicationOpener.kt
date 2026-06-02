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
import org.readium.r2.navigator.epub.EpubNavigatorFactory
import org.readium.r2.shared.util.asset.AssetRetriever
import org.readium.r2.shared.util.getOrElse
import org.readium.r2.shared.util.http.DefaultHttpClient
import org.readium.r2.shared.util.toUrl
import org.readium.r2.streamer.PublicationOpener
import org.readium.r2.streamer.parser.DefaultPublicationParser
import java.io.File
import java.io.IOException
import javax.inject.Inject

/** Downloads an EPUB (with the server's credentials) and opens it with Readium. */
class EpubPublicationOpener @Inject constructor(
    @ApplicationContext private val context: Context,
    private val clientFactory: OkHttpClientFactory,
    private val progressRepository: EpubProgressRepository,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : EpubOpener {
    override suspend fun open(server: OpdsServer, book: OpdsEntry.Book): Result<EpubSession> =
        withContext(ioDispatcher) {
            runCatching {
                val file = download(server, book)
                val httpClient = DefaultHttpClient()
                val assetRetriever = AssetRetriever(context.contentResolver, httpClient)
                val opener = PublicationOpener(
                    DefaultPublicationParser(context, httpClient, assetRetriever, pdfFactory = null),
                )
                val asset = assetRetriever.retrieve(file.toUrl())
                    .getOrElse { throw IOException("Failed to retrieve EPUB asset: $it") }
                val publication = opener.open(asset, allowUserInteraction = false)
                    .getOrElse { throw IOException("Failed to open EPUB: $it") }

                val bookId = book.numericId ?: 0L
                EpubSession(
                    publication = publication,
                    navigatorFactory = EpubNavigatorFactory(publication),
                    serverId = server.id,
                    bookId = bookId,
                    title = book.title,
                    // Progress is owned by the foliate reader now (CFI-based); this
                    // Readium path is dead code pending removal in P5.
                    initialLocator = null,
                )
            }
        }

    private fun download(server: OpdsServer, book: OpdsEntry.Book): File {
        val href = book.acquisitionHref ?: throw IOException("No acquisition link")
        val url = resolveOpdsHref(server.baseUrl, href) ?: throw IOException("Bad acquisition URL")
        val dir = File(context.cacheDir, "epubs").apply { mkdirs() }
        val file = File(dir, "${server.id}_${book.numericId ?: book.id.hashCode()}.epub")

        clientFactory.forServer(server).newCall(Request.Builder().url(url).build()).execute().use { response ->
            if (!response.isSuccessful) throw IOException("Download failed: HTTP ${response.code}")
            val body = response.body ?: throw IOException("Empty response body")
            file.outputStream().use { out -> body.byteStream().copyTo(out) }
        }
        return file
    }
}
