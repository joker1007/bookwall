package net.joker1007.bookwall.feature.servers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.network.ConnectionResult

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditServerScreen(
    onSaved: () -> Unit,
    onBack: () -> Unit,
    viewModel: AddEditServerViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(state.saved) {
        if (state.saved) onSaved()
    }

    Scaffold(
        modifier = Modifier.testTag(ServerFormTags.ROOT),
        topBar = {
            TopAppBar(
                title = { Text(if (state.isEditing) "サーバーを編集" else "サーバーを追加") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = state.name,
                onValueChange = viewModel::onNameChange,
                label = { Text("名前") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(ServerFormTags.NAME),
            )
            OutlinedTextField(
                value = state.baseUrl,
                onValueChange = viewModel::onBaseUrlChange,
                label = { Text("OPDS URL") },
                placeholder = { Text("https://example.com/opds") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(ServerFormTags.URL),
            )

            AuthTypeDropdown(
                selected = state.authType,
                onSelected = viewModel::onAuthTypeChange,
            )

            if (state.authType == AuthType.BASIC) {
                OutlinedTextField(
                    value = state.username,
                    onValueChange = viewModel::onUsernameChange,
                    label = { Text("ユーザー名") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag(ServerFormTags.USERNAME),
                )
                OutlinedTextField(
                    value = state.password,
                    onValueChange = viewModel::onPasswordChange,
                    label = { Text("パスワード") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag(ServerFormTags.PASSWORD),
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("自己署名証明書を許可", style = MaterialTheme.typography.bodyLarge)
                    Text(
                        "信頼できるサーバーにのみ使用してください",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = state.allowSelfSignedCert,
                    onCheckedChange = viewModel::onAllowSelfSignedChange,
                    modifier = Modifier.testTag(ServerFormTags.SELF_SIGNED_SWITCH),
                )
            }

            TestStatusLabel(state.testStatus)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = viewModel::testConnection,
                    enabled = state.baseUrl.isNotBlank() && state.testStatus != TestStatus.Testing,
                    modifier = Modifier
                        .weight(1f)
                        .testTag(ServerFormTags.TEST_BUTTON),
                ) {
                    Text("接続テスト")
                }
                Button(
                    onClick = viewModel::save,
                    enabled = state.canSave,
                    modifier = Modifier
                        .weight(1f)
                        .testTag(ServerFormTags.SAVE_BUTTON),
                ) {
                    Text("保存")
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AuthTypeDropdown(selected: AuthType, onSelected: (AuthType) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
    ) {
        OutlinedTextField(
            value = authTypeLabel(selected),
            onValueChange = {},
            readOnly = true,
            label = { Text("認証方式") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor(androidx.compose.material3.ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                .fillMaxWidth()
                .testTag(ServerFormTags.AUTH_TYPE),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            AuthType.entries.forEach { type ->
                DropdownMenuItem(
                    text = { Text(authTypeLabel(type)) },
                    onClick = {
                        onSelected(type)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun TestStatusLabel(status: TestStatus) {
    val (text, isError) = when (status) {
        TestStatus.Idle -> return
        TestStatus.Testing -> "接続テスト中..." to false
        is TestStatus.Done -> connectionResultMessage(status.result)
    }
    Text(
        text = text,
        color = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
        style = MaterialTheme.typography.bodyMedium,
        modifier = Modifier.testTag(ServerFormTags.TEST_RESULT),
    )
}

private fun connectionResultMessage(result: ConnectionResult): Pair<String, Boolean> = when (result) {
    is ConnectionResult.Success -> "接続成功 (${result.httpCode})" to false
    ConnectionResult.AuthFailed -> "認証に失敗しました (401)" to true
    is ConnectionResult.HttpError -> "サーバーエラー (${result.httpCode})" to true
    ConnectionResult.InvalidUrl -> "URL が不正です" to true
    is ConnectionResult.NetworkError -> "接続できません: ${result.message ?: "ネットワークエラー"}" to true
}

private fun authTypeLabel(type: AuthType): String = when (type) {
    AuthType.NONE -> "なし"
    AuthType.BASIC -> "Basic 認証"
}

object ServerFormTags {
    const val ROOT = "server_form_root"
    const val NAME = "server_form_name"
    const val URL = "server_form_url"
    const val AUTH_TYPE = "server_form_auth_type"
    const val USERNAME = "server_form_username"
    const val PASSWORD = "server_form_password"
    const val SELF_SIGNED_SWITCH = "server_form_self_signed"
    const val TEST_BUTTON = "server_form_test"
    const val SAVE_BUTTON = "server_form_save"
    const val TEST_RESULT = "server_form_test_result"
}
