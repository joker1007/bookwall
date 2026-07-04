package net.joker1007.bookwall.feature.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

private val SIZE_OPTIONS = listOf(
    1L * 1024 * 1024 * 1024 to "1GB",
    2L * 1024 * 1024 * 1024 to "2GB",
    5L * 1024 * 1024 * 1024 to "5GB",
    10L * 1024 * 1024 * 1024 to "10GB",
    20L * 1024 * 1024 * 1024 to "20GB",
    0L to "無制限",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val settings by viewModel.settings.collectAsState()
    val usage by viewModel.usageBytes.collectAsState()
    var confirmDeleteAll by remember { mutableStateOf(false) }

    Scaffold(
        modifier = Modifier.testTag(SettingsTags.ROOT),
        topBar = {
            TopAppBar(
                title = { Text("設定") },
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
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState()),
        ) {
            Text(
                "オフラインキャッシュ",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
            SwitchRow(
                title = "Wi-Fi 接続時のみダウンロード",
                description = "オフにするとモバイル回線でもダウンロードします",
                checked = settings.wifiOnly,
                onCheckedChange = viewModel::setWifiOnly,
                testTag = SettingsTags.WIFI_ONLY_SWITCH,
            )
            SwitchRow(
                title = "読んだ本を自動でキャッシュ",
                description = "リーダーで開いた本をバックグラウンドで保存します",
                checked = settings.autoCacheOnRead,
                onCheckedChange = viewModel::setAutoCacheOnRead,
                testTag = SettingsTags.AUTO_CACHE_SWITCH,
            )
            SizeLimitRow(
                current = settings.maxCacheBytes,
                onSelect = viewModel::setMaxCacheBytes,
            )
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Text(
                "現在の使用量: ${formatBytes(usage)}",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .testTag(SettingsTags.USAGE),
            )
            OutlinedButton(
                onClick = { confirmDeleteAll = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .testTag(SettingsTags.DELETE_ALL_BUTTON),
            ) {
                Text("キャッシュを全て削除")
            }
        }
    }

    if (confirmDeleteAll) {
        AlertDialog(
            onDismissRequest = { confirmDeleteAll = false },
            title = { Text("キャッシュを全て削除") },
            text = { Text("ダウンロード済みの書籍ファイルを全て削除しますか?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmDeleteAll = false
                        viewModel.deleteAllCache()
                    },
                    modifier = Modifier.testTag(SettingsTags.DELETE_ALL_CONFIRM),
                ) {
                    Text("削除")
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDeleteAll = false }) { Text("キャンセル") }
            },
        )
    }
}

@Composable
private fun SwitchRow(
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    testTag: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.testTag(testTag),
        )
    }
}

@Composable
private fun SizeLimitRow(current: Long, onSelect: (Long) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val currentLabel = SIZE_OPTIONS.firstOrNull { it.first == current }?.second
        ?: formatBytes(current)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = true }
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .testTag(SettingsTags.SIZE_LIMIT_ROW),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text("キャッシュ上限サイズ", style = MaterialTheme.typography.bodyLarge)
            Text(
                "超過すると古い順に自動削除されます",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(currentLabel, style = MaterialTheme.typography.bodyMedium)
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            SIZE_OPTIONS.forEach { (bytes, label) ->
                DropdownMenuItem(
                    text = { Text(label) },
                    onClick = {
                        onSelect(bytes)
                        expanded = false
                    },
                )
            }
        }
    }
}

private fun formatBytes(bytes: Long): String {
    var value = bytes.toDouble()
    val units = listOf("B", "KB", "MB", "GB")
    var index = 0
    while (value >= 1024 && index < units.lastIndex) {
        value /= 1024
        index++
    }
    return if (index == 0) "${bytes}B" else "%.1f%s".format(value, units[index])
}

object SettingsTags {
    const val ROOT = "settings_root"
    const val WIFI_ONLY_SWITCH = "settings_wifi_only"
    const val AUTO_CACHE_SWITCH = "settings_auto_cache"
    const val SIZE_LIMIT_ROW = "settings_size_limit"
    const val USAGE = "settings_usage"
    const val DELETE_ALL_BUTTON = "settings_delete_all"
    const val DELETE_ALL_CONFIRM = "settings_delete_all_confirm"
}
