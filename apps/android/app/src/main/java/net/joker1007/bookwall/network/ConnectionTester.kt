package net.joker1007.bookwall.network

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.di.IoDispatcher
import okhttp3.Request
import java.io.IOException
import javax.inject.Inject

sealed interface ConnectionResult {
    data class Success(val httpCode: Int) : ConnectionResult
    data object AuthFailed : ConnectionResult
    data class HttpError(val httpCode: Int) : ConnectionResult
    data object InvalidUrl : ConnectionResult
    data class NetworkError(val message: String?) : ConnectionResult
}

/** Verifies that an OPDS server is reachable with the given credentials. */
class ConnectionTester @Inject constructor(
    private val clientFactory: OkHttpClientFactory,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    suspend fun test(server: OpdsServer): ConnectionResult = withContext(ioDispatcher) {
        val request = try {
            Request.Builder().url(server.baseUrl).get().build()
        } catch (_: IllegalArgumentException) {
            return@withContext ConnectionResult.InvalidUrl
        }
        try {
            clientFactory.forServer(server).newCall(request).execute().use { response ->
                when {
                    response.isSuccessful -> ConnectionResult.Success(response.code)
                    response.code == 401 -> ConnectionResult.AuthFailed
                    else -> ConnectionResult.HttpError(response.code)
                }
            }
        } catch (e: IOException) {
            ConnectionResult.NetworkError(e.message)
        }
    }
}
