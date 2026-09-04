package net.joker1007.bookwall.data.opds

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.di.IoDispatcher
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Request
import org.xmlpull.v1.XmlPullParserException
import java.io.IOException
import javax.inject.Inject

sealed interface FeedResult {
    data class Success(val feed: OpdsFeed) : FeedResult
    data object AuthFailed : FeedResult
    data class HttpError(val code: Int) : FeedResult
    data object InvalidUrl : FeedResult
    data object ParseError : FeedResult
    data class NetworkError(val message: String?) : FeedResult
}

class OpdsRepository @Inject constructor(
    private val clientFactory: OkHttpClientFactory,
    private val parser: FeedParser,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    /** Fetches and parses the OPDS feed at [url] using [server]'s credentials. */
    suspend fun fetchFeed(server: OpdsServer, url: String): FeedResult = withContext(ioDispatcher) {
        val request = try {
            Request.Builder().url(url).get().build()
        } catch (_: IllegalArgumentException) {
            return@withContext FeedResult.InvalidUrl
        }
        try {
            clientFactory.forServer(server).newCall(request).execute().use { response ->
                when {
                    response.isSuccessful -> {
                        val body = response.body
                        try {
                            FeedResult.Success(parser.parse(body.byteStream()))
                        } catch (_: XmlPullParserException) {
                            FeedResult.ParseError
                        }
                    }
                    response.code == 401 -> FeedResult.AuthFailed
                    else -> FeedResult.HttpError(response.code)
                }
            }
        } catch (e: IOException) {
            FeedResult.NetworkError(e.message)
        }
    }
}

/** Resolves an OPDS [href] (absolute or relative) against [baseUrl]. */
fun resolveOpdsHref(baseUrl: String, href: String): String? =
    baseUrl.toHttpUrlOrNull()?.resolve(href)?.toString()
