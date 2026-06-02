package net.joker1007.bookwall.feature.epubreader

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
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
import net.joker1007.bookwall.data.epub.EpubSettings
import net.joker1007.bookwall.data.epub.EpubTheme
import org.readium.r2.shared.publication.Link

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EpubReaderChrome(
    title: String,
    toc: List<Link>,
    viewModel: EpubReaderViewModel,
    onTocClick: (Link) -> Unit,
    onBack: () -> Unit,
) {
    val chrome by viewModel.chrome.collectAsState()
    val settings by viewModel.settings.collectAsState()

    if (chrome.menuVisible) {
        TopAppBar(
            title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                }
            },
            actions = {
                IconButton(onClick = viewModel::openToc, modifier = Modifier.testTag(EpubChromeTags.TOC_BUTTON)) {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = "目次")
                }
                IconButton(onClick = viewModel::openSettings, modifier = Modifier.testTag(EpubChromeTags.SETTINGS_BUTTON)) {
                    Icon(Icons.Default.Settings, contentDescription = "設定")
                }
            },
            modifier = Modifier.testTag(EpubChromeTags.TOP_BAR),
        )
    }

    if (chrome.settingsVisible) {
        EpubSettingsSheet(settings, viewModel, onDismiss = viewModel::closeSettings)
    }

    if (chrome.tocVisible) {
        ModalBottomSheet(onDismissRequest = viewModel::closeToc) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag(EpubChromeTags.TOC_SHEET),
            ) {
                items(toc) { link ->
                    Text(
                        text = link.title ?: link.href.toString(),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onTocClick(link) }
                            .padding(horizontal = 24.dp, vertical = 12.dp),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EpubSettingsSheet(
    settings: EpubSettings,
    viewModel: EpubReaderViewModel,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .testTag(EpubChromeTags.SETTINGS_SHEET),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("表示設定", style = MaterialTheme.typography.titleMedium)

            Text("テーマ", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ThemeChip("ライト", EpubTheme.LIGHT, settings.theme, viewModel::setTheme)
                ThemeChip("セピア", EpubTheme.SEPIA, settings.theme, viewModel::setTheme)
                ThemeChip("ダーク", EpubTheme.DARK, settings.theme, viewModel::setTheme)
            }

            Text("文字サイズ: ${settings.fontSizePercent}%", style = MaterialTheme.typography.labelLarge)
            Slider(
                value = settings.fontSizePercent.toFloat(),
                onValueChange = { viewModel.setFontSizePercent(it.toInt()) },
                valueRange = 50f..250f,
                modifier = Modifier.testTag(EpubChromeTags.FONT_SLIDER),
            )

            SwitchRow("縦書き", settings.verticalText, viewModel::setVerticalText, EpubChromeTags.VERTICAL_SWITCH)
            SwitchRow("スクロール表示", settings.scroll, viewModel::setScroll, EpubChromeTags.SCROLL_SWITCH)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThemeChip(label: String, theme: EpubTheme, selected: EpubTheme, onSelect: (EpubTheme) -> Unit) {
    FilterChip(
        selected = theme == selected,
        onClick = { onSelect(theme) },
        label = { Text(label) },
    )
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit, testTag: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onChange, modifier = Modifier.testTag(testTag))
    }
}

object EpubChromeTags {
    const val TOP_BAR = "epub_top_bar"
    const val TOC_BUTTON = "epub_toc_button"
    const val SETTINGS_BUTTON = "epub_settings_button"
    const val SETTINGS_SHEET = "epub_settings_sheet"
    const val TOC_SHEET = "epub_toc_sheet"
    const val FONT_SLIDER = "epub_font_slider"
    const val VERTICAL_SWITCH = "epub_vertical_switch"
    const val SCROLL_SWITCH = "epub_scroll_switch"
}
