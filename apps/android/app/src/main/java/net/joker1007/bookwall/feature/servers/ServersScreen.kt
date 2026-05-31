package net.joker1007.bookwall.feature.servers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * Placeholder for the OPDS server list screen (Phase 1).
 * Tagged for Robot-pattern E2E verification.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServersScreen() {
    Scaffold(
        modifier = Modifier.testTag(ServersScreenTags.ROOT),
        topBar = { TopAppBar(title = { Text("Bookwall") }) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
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
        }
    }
}

object ServersScreenTags {
    const val ROOT = "servers_screen_root"
    const val EMPTY_MESSAGE = "servers_empty_message"
}
