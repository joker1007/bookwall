package net.joker1007.bookwall.data.crypto

/**
 * Symmetric encryption for credentials stored at rest. Implementations must
 * produce a self-contained, decryptable string (IV embedded).
 */
interface SecretCipher {
    fun encrypt(plaintext: String): String

    fun decrypt(ciphertext: String): String
}
