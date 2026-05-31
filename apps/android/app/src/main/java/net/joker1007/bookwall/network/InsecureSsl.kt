package net.joker1007.bookwall.network

import okhttp3.OkHttpClient
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

/**
 * Trust manager that accepts any certificate. Used ONLY for servers the user
 * has explicitly opted into self-signed certificates for — never by default.
 */
internal object TrustAllManager : X509TrustManager {
    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit
    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit
    override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
}

/** Configures [builder] to accept self-signed certificates (per explicit user opt-in). */
internal fun OkHttpClient.Builder.allowSelfSignedCertificates(): OkHttpClient.Builder {
    val sslContext = SSLContext.getInstance("TLS").apply {
        init(null, arrayOf(TrustAllManager), SecureRandom())
    }
    sslSocketFactory(sslContext.socketFactory, TrustAllManager)
    hostnameVerifier { _, _ -> true }
    return this
}
