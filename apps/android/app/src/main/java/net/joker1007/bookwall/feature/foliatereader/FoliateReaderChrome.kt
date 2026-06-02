package net.joker1007.bookwall.feature.foliatereader

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
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
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import android.app.Activity
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import net.joker1007.bookwall.data.epub.EpubSettings
import net.joker1007.bookwall.data.epub.EpubTheme
import net.joker1007.bookwall.feature.epubreader.EpubReaderViewModel

/** A table-of-contents entry parsed from foliate's book.toc JSON. */
data class TocEntry(val label: String, val href: String?, val depth: Int)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoliateReaderChrome(
    title: String,
    toc: List<TocEntry>,
    fraction: Float,
    viewModel: EpubReaderViewModel,
    onTocClick: (TocEntry) -> Unit,
    onSeek: (Float) -> Unit,
    onBack: () -> Unit,
) {
    val chrome by viewModel.chrome.collectAsState()
    val settings by viewModel.settings.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        if (chrome.menuVisible) {
            TopAppBar(
                title = { Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
                actions = {
                    IconButton(onClick = viewModel::openToc, modifier = Modifier.testTag(FoliateChromeTags.TOC_BUTTON)) {
                        Icon(Icons.AutoMirrored.Filled.List, contentDescription = "目次")
                    }
                    IconButton(onClick = viewModel::openSettings, modifier = Modifier.testTag(FoliateChromeTags.SETTINGS_BUTTON)) {
                        Icon(Icons.Default.Settings, contentDescription = "設定")
                    }
                },
                modifier = Modifier.align(Alignment.TopCenter).testTag(FoliateChromeTags.TOP_BAR),
            )

            FoliateScrubber(
                fraction = fraction,
                onSeek = onSeek,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }

    if (chrome.settingsVisible) {
        FoliateSettingsSheet(settings, viewModel, onDismiss = viewModel::closeSettings)
    }

    if (chrome.tocVisible) {
        ModalBottomSheet(onDismissRequest = viewModel::closeToc) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag(FoliateChromeTags.TOC_SHEET),
            ) {
                items(toc) { entry ->
                    Text(
                        text = entry.label,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = entry.href != null) { onTocClick(entry) }
                            .padding(start = (24 + entry.depth * 16).dp, end = 24.dp)
                            .padding(vertical = 12.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun FoliateScrubber(
    fraction: Float,
    onSeek: (Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    var dragging by remember { mutableStateOf<Float?>(null) }
    val shown = dragging ?: fraction

    Surface(color = Color.Black.copy(alpha = 0.6f), modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text(
                text = "${(shown * 100).toInt()}%",
                color = Color.White,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )
            Slider(
                value = shown.coerceIn(0f, 1f),
                onValueChange = { dragging = it },
                onValueChangeFinished = {
                    dragging?.let(onSeek)
                    dragging = null
                },
                valueRange = 0f..1f,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(FoliateChromeTags.SCRUBBER),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FoliateSettingsSheet(
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
                .testTag(FoliateChromeTags.SETTINGS_SHEET),
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
                modifier = Modifier.testTag(FoliateChromeTags.FONT_SLIDER),
            )

            // null (auto) shows as off; turning it off returns to auto-detection
            // so vertical CJK books keep working without a forced setting.
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("縦書き(強制)", style = MaterialTheme.typography.bodyLarge)
                Switch(
                    checked = settings.verticalText == true,
                    onCheckedChange = { on -> viewModel.setVerticalText(if (on) true else null) },
                    modifier = Modifier.testTag(FoliateChromeTags.VERTICAL_SWITCH),
                )
            }
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

/**
 * Hides the system bars for immersive reading (shown again with the menu) and
 * lets content extend into the display cutout. Restores defaults on leaving.
 * Ported from the image reader's ImmersiveReaderEffect.
 */
@Composable
fun FoliateImmersiveEffect(menuVisible: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    val window = (view.context as Activity).window
    val controller = remember(window, view) { WindowCompat.getInsetsController(window, view) }

    DisposableEffect(Unit) {
        val originalCutoutMode = window.attributes.layoutInDisplayCutoutMode
        val originalLightStatus = controller.isAppearanceLightStatusBars
        val originalLightNav = controller.isAppearanceLightNavigationBars
        window.attributes = window.attributes.apply {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        onDispose {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = originalCutoutMode
            }
            controller.isAppearanceLightStatusBars = originalLightStatus
            controller.isAppearanceLightNavigationBars = originalLightNav
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }

    LaunchedEffect(menuVisible) {
        if (menuVisible) {
            controller.show(WindowInsetsCompat.Type.systemBars())
        } else {
            controller.hide(WindowInsetsCompat.Type.systemBars())
        }
    }
}

object FoliateChromeTags {
    const val TOP_BAR = "foliate_top_bar"
    const val TOC_BUTTON = "foliate_toc_button"
    const val SETTINGS_BUTTON = "foliate_settings_button"
    const val SETTINGS_SHEET = "foliate_settings_sheet"
    const val TOC_SHEET = "foliate_toc_sheet"
    const val FONT_SLIDER = "foliate_font_slider"
    const val VERTICAL_SWITCH = "foliate_vertical_switch"
    const val SCRUBBER = "foliate_scrubber"
}
