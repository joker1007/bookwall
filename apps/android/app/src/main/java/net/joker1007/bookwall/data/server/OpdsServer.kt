package net.joker1007.bookwall.data.server

/**
 * Domain model for a registered OPDS server. The [password] is held in plaintext
 * in memory only; at rest it is encrypted (see ServerRepository / SecretCipher).
 */
data class OpdsServer(
    val id: Long = 0,
    val name: String,
    val baseUrl: String,
    val authType: AuthType = AuthType.NONE,
    val username: String? = null,
    val password: String? = null,
    val allowSelfSignedCert: Boolean = false,
)
