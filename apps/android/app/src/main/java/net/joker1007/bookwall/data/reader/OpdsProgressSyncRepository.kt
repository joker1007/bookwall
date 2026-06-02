package net.joker1007.bookwall.data.reader

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.opds.resolveOpdsHref
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.di.IoDispatcher
import net.joker1007.bookwall.network.OkHttpClientFactory
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import javax.inject.Inject

class OpdsProgressSyncRepository @Inject constructor(
    private val clientFactory: OkHttpClientFactory,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : ProgressSyncRepository {

    override suspend fun pushPageProgress(
        server: OpdsServer,
        bookId: Long,
        page: Int,
        pageCount: Int,
    ): Boolean = put(server, bookId, """{"current_page":$page}""")

    override suspend fun pushEpubProgress(
        server: OpdsServer,
        bookId: Long,
        cfi: String,
        fraction: Float,
    ): Boolean {
        val body = JSONObject()
            .put("epub_cfi", cfi)
            .put("progress_fraction", fraction.toDouble())
            .toString()
        return put(server, bookId, body)
    }

    override suspend fun pullEpubProgress(server: OpdsServer, bookId: Long): RemoteEpubProgress? {
        val url = progressUrl(server, bookId) ?: return null
        val request = Request.Builder().url(url).get().build()
        return withContext(ioDispatcher) {
            try {
                clientFactory.forServer(server).newCall(request).execute().use { response ->
                    if (!response.isSuccessful) return@use null
                    val text = response.body?.string() ?: return@use null
                    val json = JSONObject(text)
                    RemoteEpubProgress(
                        cfi = json.optString("epub_cfi").ifEmpty { null },
                        fraction = if (json.isNull("progress_fraction")) null else json.optDouble("progress_fraction").toFloat(),
                    )
                }
            } catch (_: IOException) {
                null
            } catch (_: org.json.JSONException) {
                null
            }
        }
    }

    private fun progressUrl(server: OpdsServer, bookId: Long): String? {
        val template = server.syncProgressTemplate?.ifEmpty { null } ?: return null
        val path = template.replace(OpdsParser.BOOK_ID_TOKEN, bookId.toString())
        return resolveOpdsHref(server.baseUrl, path)
    }

    private suspend fun put(server: OpdsServer, bookId: Long, json: String): Boolean {
        val url = progressUrl(server, bookId) ?: return false
        val request = Request.Builder().url(url).put(json.toRequestBody(JSON_MEDIA_TYPE)).build()
        return withContext(ioDispatcher) {
            try {
                clientFactory.forServer(server).newCall(request).execute().use { it.isSuccessful }
            } catch (_: IOException) {
                false
            }
        }
    }

    private companion object {
        val JSON_MEDIA_TYPE = "application/json".toMediaType()
    }
}
