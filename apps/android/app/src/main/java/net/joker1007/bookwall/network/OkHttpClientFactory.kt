package net.joker1007.bookwall.network

import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import okhttp3.OkHttpClient
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Derives a per-server [OkHttpClient] from a shared base client, layering on
 * Basic auth and self-signed certificate trust according to the server config.
 */
@Singleton
class OkHttpClientFactory @Inject constructor(
    private val baseClient: OkHttpClient,
) {
    fun forServer(server: OpdsServer): OkHttpClient {
        val builder = baseClient.newBuilder()
        if (server.authType == AuthType.BASIC && !server.username.isNullOrEmpty()) {
            builder.addInterceptor(BasicAuthInterceptor(server.username, server.password.orEmpty()))
        }
        if (server.allowSelfSignedCert) {
            builder.allowSelfSignedCertificates()
        }
        return builder.build()
    }
}
