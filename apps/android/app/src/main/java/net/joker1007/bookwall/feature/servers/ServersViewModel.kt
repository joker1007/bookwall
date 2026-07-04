package net.joker1007.bookwall.feature.servers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.cache.BookCacheRepository
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import javax.inject.Inject

@HiltViewModel
class ServersViewModel @Inject constructor(
    private val repository: ServerRepository,
    private val bookCacheRepository: BookCacheRepository,
) : ViewModel() {

    val servers: StateFlow<List<OpdsServer>> = repository.observeServers()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun deleteServer(id: Long) {
        viewModelScope.launch {
            bookCacheRepository.deleteByServer(id)
            repository.delete(id)
        }
    }
}
