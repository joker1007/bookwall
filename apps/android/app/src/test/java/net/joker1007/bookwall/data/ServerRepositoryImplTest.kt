package net.joker1007.bookwall.data

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ServerRepositoryImplTest {

    private lateinit var dao: FakeOpdsServerDao
    private lateinit var repository: ServerRepositoryImpl

    @Before
    fun setUp() {
        dao = FakeOpdsServerDao()
        repository = ServerRepositoryImpl(dao, FakeSecretCipher(), clock = { FIXED_TIME })
    }

    @Test
    fun `upsert inserts a new server and assigns an id`() = runTest {
        val id = repository.upsert(
            OpdsServer(name = "Home", baseUrl = "https://h/opds", authType = AuthType.NONE),
        )

        assertEquals(1L, id)
        assertEquals("Home", repository.getServer(1L)?.name)
    }

    @Test
    fun `password is encrypted at rest and decrypted on read`() = runTest {
        val id = repository.upsert(
            OpdsServer(
                name = "Auth",
                baseUrl = "https://h/opds",
                authType = AuthType.BASIC,
                username = "user",
                password = "secret",
            ),
        )

        val stored = dao.findById(id)
        assertNotNull(stored?.encryptedPassword)
        assertTrue(stored!!.encryptedPassword!!.startsWith(FakeSecretCipher.PREFIX))

        assertEquals("secret", repository.getServer(id)?.password)
    }

    @Test
    fun `none auth clears username and password`() = runTest {
        val id = repository.upsert(
            OpdsServer(
                name = "NoAuth",
                baseUrl = "https://h/opds",
                authType = AuthType.NONE,
                username = "user",
                password = "secret",
            ),
        )

        val server = repository.getServer(id)
        assertNull(server?.username)
        assertNull(server?.password)
    }

    @Test
    fun `upsert updates an existing server in place`() = runTest {
        val id = repository.upsert(OpdsServer(name = "Old", baseUrl = "https://h/opds"))
        repository.upsert(OpdsServer(id = id, name = "New", baseUrl = "https://h2/opds"))

        assertEquals(1, repository.observeServers().first().size)
        assertEquals("New", repository.getServer(id)?.name)
    }

    @Test
    fun `delete removes the server`() = runTest {
        val id = repository.upsert(OpdsServer(name = "Tmp", baseUrl = "https://h/opds"))
        repository.delete(id)

        assertNull(repository.getServer(id))
        assertTrue(repository.observeServers().first().isEmpty())
    }

    private companion object {
        const val FIXED_TIME = 1_000L
    }
}
