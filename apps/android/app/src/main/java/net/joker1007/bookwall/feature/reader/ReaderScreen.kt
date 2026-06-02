package net.joker1007.bookwall.feature.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import android.app.Activity
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.hilt.navigation.compose.hiltViewModel
import coil3.ImageLoader
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.reader.PageSource
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.reader.TapAction
import net.joker1007.bookwall.data.reader.TapZone
import net.joker1007.bookwall.data.reader.TapZoneConfig
import net.joker1007.bookwall.data.reader.buildSpreads
import net.joker1007.bookwall.data.reader.flippedForRtl
import net.joker1007.bookwall.data.reader.slotIndexForPage
import net.joker1007.bookwall.data.reader.tapTargetPage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    onBack: () -> Unit,
    viewModel: ReaderViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val imageLoader by viewModel.imageLoader.collectAsState()
    val tapConfig by viewModel.tapZoneConfig.collectAsState()

    ImmersiveReaderEffect(menuVisible = state.menuVisible)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .testTag(ReaderTags.ROOT),
    ) {
        when {
            state.loading -> CircularProgressIndicator(
                modifier = Modifier
                    .align(Alignment.Center)
                    .testTag(ReaderTags.LOADING),
            )
            state.error != null -> Text(
                text = state.error!!,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.Center)
                    .testTag(ReaderTags.ERROR),
            )
            state.pageCount == 0 -> Text(
                text = "表示できるページがありません",
                color = Color.White,
                modifier = Modifier.align(Alignment.Center),
            )
            else -> {
                val slots = remember(state.pageCount, state.spreadEnabled, state.pageOffset) {
                    buildSpreads(state.pageCount, state.spreadEnabled, state.pageOffset)
                }

                key(state.spreadEnabled, state.pageOffset) {
                    val pagerState = rememberPagerState(
                        initialPage = slotIndexForPage(slots, state.currentPage),
                        pageCount = { slots.size },
                    )

                    LaunchedEffect(state.currentPage, slots) {
                        val target = slotIndexForPage(slots, state.currentPage)
                        if (pagerState.currentPage != target && !pagerState.isScrollInProgress) {
                            pagerState.animateScrollToPage(target)
                        }
                    }
                    LaunchedEffect(pagerState, slots) {
                        snapshotFlow { pagerState.currentPage }.collect { slot ->
                            slots.getOrNull(slot)?.firstOrNull()?.let(viewModel::onPageSettled)
                        }
                    }

                    val dispatchTap: (TapZone) -> Unit = { zone ->
                        val effectiveZone =
                            if (state.direction == ReadingDirection.RTL) zone.flippedForRtl() else zone
                        when (val action = tapConfig.actionFor(effectiveZone)) {
                            TapAction.TOGGLE_MENU -> viewModel.toggleMenu()
                            else -> tapTargetPage(action, slots, state.currentPage)?.let(viewModel::goToPage)
                        }
                    }

                    HorizontalPager(
                        state = pagerState,
                        reverseLayout = state.direction == ReadingDirection.RTL,
                        beyondViewportPageCount = 1,
                        modifier = Modifier
                            .fillMaxSize()
                            .testTag(ReaderTags.PAGER),
                    ) { slotIndex ->
                        SpreadSlot(
                            pages = slots[slotIndex],
                            direction = state.direction,
                            pageSource = viewModel.pageSource,
                            imageLoader = imageLoader,
                            onTapZone = dispatchTap,
                        )
                    }
                }

                if (state.menuVisible) {
                    TopAppBar(
                        title = { Text(state.title, color = Color.White) },
                        navigationIcon = {
                            IconButton(onClick = onBack) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る", tint = Color.White)
                            }
                        },
                        actions = {
                            IconButton(
                                onClick = viewModel::openSettings,
                                modifier = Modifier.testTag(ReaderTags.SETTINGS_BUTTON),
                            ) {
                                Icon(Icons.Default.Settings, contentDescription = "設定", tint = Color.White)
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black.copy(alpha = 0.6f)),
                        modifier = Modifier.align(Alignment.TopCenter),
                    )

                    PageScrubber(
                        currentPage = state.currentPage,
                        pageCount = state.pageCount,
                        pageSource = viewModel.pageSource,
                        imageLoader = imageLoader,
                        onScrub = viewModel::goToPage,
                        modifier = Modifier.align(Alignment.BottomCenter),
                    )
                }
            }
        }
    }

    if (state.settingsVisible) {
        ReaderSettingsSheet(
            direction = state.direction,
            spreadEnabled = state.spreadEnabled,
            tapConfig = tapConfig,
            onDirectionChange = viewModel::setDirection,
            onSpreadChange = viewModel::setSpread,
            onNudgeOffset = viewModel::nudgeOffset,
            onZoneAction = viewModel::setZoneAction,
            onDismiss = viewModel::closeSettings,
        )
    }
}

@Composable
private fun SpreadSlot(
    pages: List<Int>,
    direction: ReadingDirection,
    pageSource: PageSource?,
    imageLoader: ImageLoader?,
    onTapZone: (TapZone) -> Unit,
) {
    val ordered = if (direction == ReadingDirection.RTL) pages.reversed() else pages
    Row(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val third = size.width / 3f
                    val zone = when {
                        offset.x < third -> TapZone.LEFT
                        offset.x > size.width - third -> TapZone.RIGHT
                        else -> TapZone.CENTER
                    }
                    onTapZone(zone)
                }
            },
    ) {
        ordered.forEach { page ->
            Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
                imageLoader?.let { loader ->
                    AsyncImage(
                        model = pageSource?.pageModel(page),
                        contentDescription = null,
                        imageLoader = loader,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReaderSettingsSheet(
    direction: ReadingDirection,
    spreadEnabled: Boolean,
    tapConfig: TapZoneConfig,
    onDirectionChange: (ReadingDirection) -> Unit,
    onSpreadChange: (Boolean) -> Unit,
    onNudgeOffset: () -> Unit,
    onZoneAction: (TapZone, TapAction) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .testTag(ReaderTags.SETTINGS_SHEET),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("リーダー設定", style = MaterialTheme.typography.titleMedium)

            SettingSwitchRow(
                label = "右から左に読む (RTL)",
                checked = direction == ReadingDirection.RTL,
                onCheckedChange = { onDirectionChange(if (it) ReadingDirection.RTL else ReadingDirection.LTR) },
                testTag = ReaderTags.DIRECTION_SWITCH,
            )
            SettingSwitchRow(
                label = "見開き表示",
                checked = spreadEnabled,
                onCheckedChange = onSpreadChange,
                testTag = ReaderTags.SPREAD_SWITCH,
            )
            if (spreadEnabled) {
                OutlinedButton(
                    onClick = onNudgeOffset,
                    modifier = Modifier.testTag(ReaderTags.OFFSET_BUTTON),
                ) {
                    Text("ページを1つずらす")
                }
            }

            Text("タップ操作", style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 8.dp))
            Text(
                "中央タップはメニュー表示で固定。右から左に読む設定では左右が反転します。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TapZoneRow("左", tapConfig.left, { onZoneAction(TapZone.LEFT, it) }, ReaderTags.TAP_LEFT)
            TapZoneRow("右", tapConfig.right, { onZoneAction(TapZone.RIGHT, it) }, ReaderTags.TAP_RIGHT)
        }
    }
}

@Composable
private fun TapZoneRow(
    zoneLabel: String,
    action: TapAction,
    onSelect: (TapAction) -> Unit,
    testTag: String,
) {
    var expanded by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(zoneLabel, style = MaterialTheme.typography.bodyLarge)
        Box {
            TextButton(onClick = { expanded = true }, modifier = Modifier.testTag(testTag)) {
                Text(tapActionLabel(action))
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                TapAction.entries.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(tapActionLabel(option)) },
                        onClick = {
                            onSelect(option)
                            expanded = false
                        },
                    )
                }
            }
        }
    }
}

private fun tapActionLabel(action: TapAction): String = when (action) {
    TapAction.NONE -> "なし"
    TapAction.TOGGLE_MENU -> "メニュー"
    TapAction.PREVIOUS -> "前へ"
    TapAction.NEXT -> "次へ"
    TapAction.PREVIOUS_SINGLE -> "前へ(単ページ)"
    TapAction.NEXT_SINGLE -> "次へ(単ページ)"
    TapAction.PREVIOUS_CONTINUOUS -> "前へ(連続)"
    TapAction.NEXT_CONTINUOUS -> "次へ(連続)"
}

@Composable
private fun SettingSwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    testTag: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange, modifier = Modifier.testTag(testTag))
    }
}

@Composable
private fun PageScrubber(
    currentPage: Int,
    pageCount: Int,
    pageSource: PageSource?,
    imageLoader: ImageLoader?,
    onScrub: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var dragging by remember { mutableStateOf<Int?>(null) }
    val shown = dragging ?: currentPage

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (dragging != null && imageLoader != null) {
            Surface(
                color = Color.Black.copy(alpha = 0.8f),
                modifier = Modifier
                    .padding(bottom = 4.dp)
                    .testTag(ReaderTags.SCRUB_THUMBNAIL),
            ) {
                Column(
                    modifier = Modifier.padding(8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    AsyncImage(
                        model = pageSource?.pageModel(shown),
                        contentDescription = null,
                        imageLoader = imageLoader,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.size(width = 100.dp, height = 140.dp),
                    )
                    Text("${shown + 1}", color = Color.White, style = MaterialTheme.typography.labelSmall)
                }
            }
        }

        Surface(color = Color.Black.copy(alpha = 0.6f), modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    text = "${shown + 1} / $pageCount",
                    color = Color.White,
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                )
                Slider(
                    value = shown.toFloat(),
                    onValueChange = { dragging = it.toInt() },
                    onValueChangeFinished = {
                        dragging?.let(onScrub)
                        dragging = null
                    },
                    valueRange = 0f..(pageCount - 1).coerceAtLeast(1).toFloat(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag(ReaderTags.SCRUBBER),
                )
            }
        }
    }
}

/**
 * While the reader is shown, hides the system bars for immersive reading
 * (shown again when the menu is open) and lets page images extend into the
 * display cutout. Restores the defaults when leaving the reader.
 */
@Composable
private fun ImmersiveReaderEffect(menuVisible: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    val window = (view.context as Activity).window
    val controller = remember(window, view) { WindowCompat.getInsetsController(window, view) }

    DisposableEffect(Unit) {
        val originalCutoutMode = window.attributes.layoutInDisplayCutoutMode
        val originalLightStatus = controller.isAppearanceLightStatusBars
        val originalLightNav = controller.isAppearanceLightNavigationBars
        window.attributes = window.attributes.apply {
            layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        // The reader background is black, so use light (white) system bar icons.
        controller.isAppearanceLightStatusBars = false
        controller.isAppearanceLightNavigationBars = false
        onDispose {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = originalCutoutMode
            }
            controller.isAppearanceLightStatusBars = originalLightStatus
            controller.isAppearanceLightNavigationBars = originalLightNav
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }

    // Run after composition commits; toggling the controller during composition
    // can be overridden by the window's own inset pass and never take effect.
    LaunchedEffect(menuVisible) {
        if (menuVisible) {
            controller.show(WindowInsetsCompat.Type.systemBars())
        } else {
            controller.hide(WindowInsetsCompat.Type.systemBars())
        }
    }
}

object ReaderTags {
    const val ROOT = "reader_root"
    const val PAGER = "reader_pager"
    const val LOADING = "reader_loading"
    const val ERROR = "reader_error"
    const val SETTINGS_BUTTON = "reader_settings_button"
    const val SETTINGS_SHEET = "reader_settings_sheet"
    const val DIRECTION_SWITCH = "reader_direction_switch"
    const val SPREAD_SWITCH = "reader_spread_switch"
    const val OFFSET_BUTTON = "reader_offset_button"
    const val SCRUBBER = "reader_scrubber"
    const val SCRUB_THUMBNAIL = "reader_scrub_thumbnail"
    const val TAP_LEFT = "reader_tap_left"
    const val TAP_RIGHT = "reader_tap_right"
}
