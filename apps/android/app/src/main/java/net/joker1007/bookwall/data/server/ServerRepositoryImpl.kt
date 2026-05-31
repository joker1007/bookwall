package net.joker1007.bookwall.data.server

import net.joker1007.bookwall.data.crypto.SecretCipher
import net.joker1007.bookwall.data.db.OpdsServerDao
import net.joker1007.bookwall.data.db.OpdsServerEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class ServerRepositoryImpl @Inject constructor(
    private val dao: OpdsServerDao,
    private val cipher: SecretCipher,
    private val clock: () -> Long,
) : ServerRepository {

    override fun observeServers(): Flow<List<OpdsServer>> =
        dao.observeAll().map { entities -> entities.map { it.toDomain() } }

    override suspend fun getServer(id: Long): OpdsServer? = dao.findById(id)?.toDomain()

    override suspend fun upsert(server: OpdsServer): Long {
        val now = clock()
        return if (server.id == 0L) {
            dao.insert(server.toEntity(createdAt = now, updatedAt = now))
        } else {
            val existing = dao.findById(server.id)
            dao.update(server.toEntity(createdAt = existing?.createdAt ?: now, updatedAt = now))
            server.id
        }
    }

    override suspend fun delete(id: Long) = dao.deleteById(id)

    private fun OpdsServer.toEntity(createdAt: Long, updatedAt: Long) = OpdsServerEntity(
        id = id,
        name = name,
        baseUrl = baseUrl,
        authType = authType.name,
        username = username?.takeIf { authType == AuthType.BASIC },
        encryptedPassword = password
            ?.takeIf { authType == AuthType.BASIC && it.isNotEmpty() }
            ?.let { cipher.encrypt(it) },
        allowSelfSignedCert = allowSelfSignedCert,
        createdAt = createdAt,
        updatedAt = updatedAt,
    )

    private fun OpdsServerEntity.toDomain() = OpdsServer(
        id = id,
        name = name,
        baseUrl = baseUrl,
        authType = runCatching { AuthType.valueOf(authType) }.getOrDefault(AuthType.NONE),
        username = username,
        password = encryptedPassword?.let { cipher.decrypt(it) },
        allowSelfSignedCert = allowSelfSignedCert,
    )
}
