package net.joker1007.bookwall.feature.servers

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.network.ConnectionResult
import net.joker1007.bookwall.network.ConnectionTester
import javax.inject.Inject

sealed interface TestStatus {
    data object Idle : TestStatus
    data object Testing : TestStatus
    data class Done(val result: ConnectionResult) : TestStatus
}

data class ServerFormState(
    val name: String = "",
    val baseUrl: String = "",
    val authType: AuthType = AuthType.NONE,
    val username: String = "",
    val password: String = "",
    val allowSelfSignedCert: Boolean = false,
    val isEditing: Boolean = false,
    val testStatus: TestStatus = TestStatus.Idle,
    val saved: Boolean = false,
) {
    val canSave: Boolean get() = name.isNotBlank() && baseUrl.isNotBlank()
}

@HiltViewModel
class AddEditServerViewModel @Inject constructor(
    private val repository: ServerRepository,
    private val connectionTester: ConnectionTester,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val serverId: Long = savedStateHandle.get<Long>(ARG_SERVER_ID) ?: NEW_SERVER_ID

    private val _state = MutableStateFlow(ServerFormState(isEditing = serverId != NEW_SERVER_ID))
    val state: StateFlow<ServerFormState> = _state.asStateFlow()

    init {
        if (serverId != NEW_SERVER_ID) {
            viewModelScope.launch {
                repository.getServer(serverId)?.let { server ->
                    _state.update {
                        it.copy(
                            name = server.name,
                            baseUrl = server.baseUrl,
                            authType = server.authType,
                            username = server.username.orEmpty(),
                            password = server.password.orEmpty(),
                            allowSelfSignedCert = server.allowSelfSignedCert,
                        )
                    }
                }
            }
        }
    }

    fun onNameChange(value: String) = _state.update { it.copy(name = value, testStatus = TestStatus.Idle) }
    fun onBaseUrlChange(value: String) = _state.update { it.copy(baseUrl = value, testStatus = TestStatus.Idle) }
    fun onAuthTypeChange(value: AuthType) = _state.update { it.copy(authType = value, testStatus = TestStatus.Idle) }
    fun onUsernameChange(value: String) = _state.update { it.copy(username = value, testStatus = TestStatus.Idle) }
    fun onPasswordChange(value: String) = _state.update { it.copy(password = value, testStatus = TestStatus.Idle) }
    fun onAllowSelfSignedChange(value: Boolean) =
        _state.update { it.copy(allowSelfSignedCert = value, testStatus = TestStatus.Idle) }

    fun testConnection() {
        _state.update { it.copy(testStatus = TestStatus.Testing) }
        viewModelScope.launch {
            val result = connectionTester.test(buildServer())
            _state.update { it.copy(testStatus = TestStatus.Done(result)) }
        }
    }

    fun save() {
        if (!_state.value.canSave) return
        viewModelScope.launch {
            repository.upsert(buildServer())
            _state.update { it.copy(saved = true) }
        }
    }

    private fun buildServer(): OpdsServer {
        val s = _state.value
        return OpdsServer(
            id = serverId.takeIf { it != NEW_SERVER_ID } ?: 0L,
            name = s.name.trim(),
            baseUrl = s.baseUrl.trim(),
            authType = s.authType,
            username = s.username.ifBlank { null },
            password = s.password.ifEmpty { null },
            allowSelfSignedCert = s.allowSelfSignedCert,
        )
    }

    companion object {
        const val ARG_SERVER_ID = "serverId"
        const val NEW_SERVER_ID = 0L
    }
}
