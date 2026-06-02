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
    ): Boolean {
        val template = server.syncProgressTemplate?.ifEmpty { null } ?: return false
        val path = template.replace(OpdsParser.BOOK_ID_TOKEN, bookId.toString())
        val url = resolveOpdsHref(server.baseUrl, path) ?: return false

        val body = """{"current_page":$page}""".toRequestBody(JSON_MEDIA_TYPE)
        val request = Request.Builder().url(url).put(body).build()

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
