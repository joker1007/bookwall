package net.joker1007.bookwall.feature.servers

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import net.joker1007.bookwall.data.server.AuthType
import net.joker1007.bookwall.data.server.OpdsServer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServersScreen(
    onOpenServer: (Long) -> Unit,
    onAddServer: () -> Unit,
    onEditServer: (Long) -> Unit,
    viewModel: ServersViewModel = hiltViewModel(),
) {
    val servers by viewModel.servers.collectAsState()
    Scaffold(
        modifier = Modifier.testTag(ServersScreenTags.ROOT),
        topBar = { TopAppBar(title = { Text("OPDS サーバー") }) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAddServer,
                modifier = Modifier.testTag(ServersScreenTags.ADD_FAB),
            ) {
                Icon(Icons.Default.Add, contentDescription = "サーバーを追加")
            }
        },
    ) { padding ->
        if (servers.isEmpty()) {
            EmptyState(
                Modifier
                    .fillMaxSize()
                    .padding(padding),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(servers, key = { it.id }) { server ->
                    ServerRow(
                        server = server,
                        onClick = { onOpenServer(server.id) },
                        onEdit = { onEditServer(server.id) },
                        onDelete = { viewModel.deleteServer(server.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "OPDS サーバーが登録されていません",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier
                .padding(16.dp)
                .testTag(ServersScreenTags.EMPTY_MESSAGE),
        )
        Text(
            text = "右下の + から追加してください",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ServerRow(server: OpdsServer, onClick: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = server.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = server.baseUrl,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (server.authType == AuthType.BASIC) {
                    Text(text = "Basic 認証", style = MaterialTheme.typography.labelSmall)
                }
            }
            IconButton(
                onClick = onEdit,
                modifier = Modifier.testTag(ServersScreenTags.editTag(server.id)),
            ) {
                Icon(Icons.Default.Edit, contentDescription = "編集")
            }
            IconButton(
                onClick = onDelete,
                modifier = Modifier.testTag(ServersScreenTags.deleteTag(server.id)),
            ) {
                Icon(Icons.Default.Delete, contentDescription = "削除")
            }
        }
    }
}

object ServersScreenTags {
    const val ROOT = "servers_screen_root"
    const val EMPTY_MESSAGE = "servers_empty_message"
    const val ADD_FAB = "servers_add_fab"
    fun editTag(id: Long) = "servers_edit_$id"
    fun deleteTag(id: Long) = "servers_delete_$id"
}
