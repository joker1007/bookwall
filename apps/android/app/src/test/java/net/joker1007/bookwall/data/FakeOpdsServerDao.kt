package net.joker1007.bookwall.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import net.joker1007.bookwall.data.db.OpdsServerDao
import net.joker1007.bookwall.data.db.OpdsServerEntity

/** In-memory [OpdsServerDao] for JVM unit tests. */
class FakeOpdsServerDao : OpdsServerDao {
    private val rows = MutableStateFlow<List<OpdsServerEntity>>(emptyList())
    private var nextId = 1L

    override fun observeAll(): Flow<List<OpdsServerEntity>> =
        rows.map { list -> list.sortedBy { it.name.lowercase() } }

    override suspend fun findById(id: Long): OpdsServerEntity? = rows.value.find { it.id == id }

    override suspend fun insert(entity: OpdsServerEntity): Long {
        val id = nextId++
        rows.value = rows.value + entity.copy(id = id)
        return id
    }

    override suspend fun update(entity: OpdsServerEntity) {
        rows.value = rows.value.map { if (it.id == entity.id) entity else it }
    }

    override suspend fun deleteById(id: Long) {
        rows.value = rows.value.filterNot { it.id == id }
    }
}
