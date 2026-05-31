package net.joker1007.bookwall.data.server

import kotlinx.coroutines.flow.Flow

interface ServerRepository {
    fun observeServers(): Flow<List<OpdsServer>>

    suspend fun getServer(id: Long): OpdsServer?

    /** Inserts a new server (id == 0) or updates an existing one. Returns the id. */
    suspend fun upsert(server: OpdsServer): Long

    suspend fun delete(id: Long)
}
