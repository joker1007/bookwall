package net.joker1007.bookwall.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "opds_servers")
data class OpdsServerEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val baseUrl: String,
    val authType: String,
    val username: String?,
    /** Base64-encoded "iv:ciphertext"; null when no password is stored. */
    val encryptedPassword: String?,
    val allowSelfSignedCert: Boolean,
    val createdAt: Long,
    val updatedAt: Long,
)
