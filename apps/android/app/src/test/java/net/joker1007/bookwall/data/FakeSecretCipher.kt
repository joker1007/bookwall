package net.joker1007.bookwall.data

import net.joker1007.bookwall.data.crypto.SecretCipher

/** Reversible non-secret cipher used to assert encryption round-trips in tests. */
class FakeSecretCipher : SecretCipher {
    override fun encrypt(plaintext: String): String = "$PREFIX$plaintext"

    override fun decrypt(ciphertext: String): String = ciphertext.removePrefix(PREFIX)

    companion object {
        const val PREFIX = "enc:"
    }
}
