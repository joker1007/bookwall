package net.joker1007.bookwall.feature.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.reader.ReadingDirection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    onBack: () -> Unit,
    viewModel: ReaderViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val imageLoader by viewModel.imageLoader.collectAsState()

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
                val pagerState = rememberPagerState(initialPage = state.currentPage, pageCount = { state.pageCount })

                LaunchedEffect(state.currentPage) {
                    if (pagerState.currentPage != state.currentPage && !pagerState.isScrollInProgress) {
                        pagerState.animateScrollToPage(state.currentPage)
                    }
                }
                LaunchedEffect(pagerState) {
                    snapshotFlow { pagerState.currentPage }.collect(viewModel::onPageSettled)
                }

                HorizontalPager(
                    state = pagerState,
                    reverseLayout = state.direction == ReadingDirection.RTL,
                    beyondViewportPageCount = 1,
                    modifier = Modifier
                        .fillMaxSize()
                        .testTag(ReaderTags.PAGER),
                ) { page ->
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .pointerInput(state.direction) {
                                detectTapGestures { offset ->
                                    val third = size.width / 3f
                                    when {
                                        offset.x < third ->
                                            if (state.direction == ReadingDirection.LTR) viewModel.previous() else viewModel.next()
                                        offset.x > size.width - third ->
                                            if (state.direction == ReadingDirection.LTR) viewModel.next() else viewModel.previous()
                                        else -> viewModel.toggleMenu()
                                    }
                                }
                            },
                    ) {
                        imageLoader?.let { loader ->
                            AsyncImage(
                                model = viewModel.pageSource?.pageModel(page),
                                contentDescription = null,
                                imageLoader = loader,
                                contentScale = ContentScale.Fit,
                                modifier = Modifier.fillMaxSize(),
                            )
                        }
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
                                onClick = {
                                    viewModel.setDirection(
                                        if (state.direction == ReadingDirection.LTR) ReadingDirection.RTL else ReadingDirection.LTR,
                                    )
                                },
                                modifier = Modifier.testTag(ReaderTags.DIRECTION_TOGGLE),
                            ) {
                                Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = "読む方向", tint = Color.White)
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black.copy(alpha = 0.6f)),
                        modifier = Modifier.align(Alignment.TopCenter),
                    )

                    PageScrubber(
                        currentPage = state.currentPage,
                        pageCount = state.pageCount,
                        onScrub = { viewModel.goToPage(it) },
                        modifier = Modifier.align(Alignment.BottomCenter),
                    )
                }
            }
        }
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
    const val DIRECTION_TOGGLE = "reader_direction_toggle"
    const val SCRUBBER = "reader_scrubber"
}
