package net.joker1007.bookwall.feature.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil3.ImageLoader
import coil3.compose.AsyncImage
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.reader.PageSource
import net.joker1007.bookwall.data.reader.ReadingDirection
import net.joker1007.bookwall.data.reader.buildSpreads
import net.joker1007.bookwall.data.reader.slotIndexForPage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    onBack: () -> Unit,
    viewModel: ReaderViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val imageLoader by viewModel.imageLoader.collectAsState()
    val scope = rememberCoroutineScope()

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

                    val advance: (Boolean) -> Unit = { forward ->
                        val target = (if (forward) pagerState.currentPage + 1 else pagerState.currentPage - 1)
                            .coerceIn(0, slots.lastIndex.coerceAtLeast(0))
                        scope.launch { pagerState.animateScrollToPage(target) }
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
                            onLeftTap = { if (state.direction == ReadingDirection.LTR) advance(false) else advance(true) },
                            onRightTap = { if (state.direction == ReadingDirection.LTR) advance(true) else advance(false) },
                            onCenterTap = viewModel::toggleMenu,
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
            onDirectionChange = viewModel::setDirection,
            onSpreadChange = viewModel::setSpread,
            onNudgeOffset = viewModel::nudgeOffset,
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
    onLeftTap: () -> Unit,
    onRightTap: () -> Unit,
    onCenterTap: () -> Unit,
) {
    val ordered = if (direction == ReadingDirection.RTL) pages.reversed() else pages
    Row(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(direction) {
                detectTapGestures { offset ->
                    val third = size.width / 3f
                    when {
                        offset.x < third -> onLeftTap()
                        offset.x > size.width - third -> onRightTap()
                        else -> onCenterTap()
                    }
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
    onDirectionChange: (ReadingDirection) -> Unit,
    onSpreadChange: (Boolean) -> Unit,
    onNudgeOffset: () -> Unit,
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
        }
    }
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
    onScrub: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = Color.Black.copy(alpha = 0.6f),
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            Text(
                text = "${currentPage + 1} / $pageCount",
                color = Color.White,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )
            Slider(
                value = currentPage.toFloat(),
                onValueChange = { onScrub(it.toInt()) },
                valueRange = 0f..(pageCount - 1).coerceAtLeast(1).toFloat(),
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag(ReaderTags.SCRUBBER),
            )
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
}
