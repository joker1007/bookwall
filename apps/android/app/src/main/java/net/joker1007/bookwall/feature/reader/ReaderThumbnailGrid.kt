package net.joker1007.bookwall.feature.reader

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import coil3.ImageLoader
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.reader.PageSource
import net.joker1007.bookwall.data.reader.ReadingDirection

/**
 * Full-screen overlay listing every page as a thumbnail. Cells are composed
 * lazily by the grid, so only pages scrolled into view are ever requested.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderThumbnailGrid(
    currentPage: Int,
    pageCount: Int,
    direction: ReadingDirection,
    pageSource: PageSource?,
    imageLoader: ImageLoader?,
    onSelect: (Int) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BackHandler(onBack = onClose)

    val gridState = rememberLazyGridState(initialFirstVisibleItemIndex = currentPage)
    val layoutDirection =
        if (direction == ReadingDirection.RTL) LayoutDirection.Rtl else LayoutDirection.Ltr

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
            // Swallow taps so they never fall through to the pager's tap zones.
            .clickable(enabled = false, onClick = {})
            .testTag(ReaderTags.THUMBNAIL_GRID),
    ) {
        TopAppBar(
            title = { Text("サムネイル一覧", color = Color.White) },
            actions = {
                IconButton(
                    onClick = onClose,
                    modifier = Modifier.testTag(ReaderTags.THUMBNAIL_CLOSE),
                ) {
                    Icon(Icons.Default.Close, contentDescription = "サムネイル一覧を閉じる", tint = Color.White)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black),
        )
        CompositionLocalProvider(LocalLayoutDirection provides layoutDirection) {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = CELL_MIN_WIDTH),
                state = gridState,
                contentPadding = PaddingValues(8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .testTag(ReaderTags.THUMBNAIL_LIST),
            ) {
                items(count = pageCount, key = { it }) { page ->
                    ThumbnailCell(
                        page = page,
                        current = page == currentPage,
                        pageSource = pageSource,
                        imageLoader = imageLoader,
                        onClick = { onSelect(page) },
                    )
                }
                item(key = "bottom_inset", span = { GridItemSpan(maxLineSpan) }) {
                    Box(modifier = Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
                }
            }
        }
    }
}

@Composable
private fun ThumbnailCell(
    page: Int,
    current: Boolean,
    pageSource: PageSource?,
    imageLoader: ImageLoader?,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(6.dp)
    val label = thumbnailLabel(page)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .clip(shape)
            .background(if (current) Color.White.copy(alpha = 0.2f) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(4.dp)
            .semantics { contentDescription = label }
            .testTag(ReaderTags.thumbnailTag(page)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(shape)
                .background(Color.White.copy(alpha = 0.05f))
                .then(
                    if (current) Modifier.border(2.dp, Color.White, shape) else Modifier,
                ),
        ) {
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
        Text(
            text = "${page + 1}",
            color = if (current) Color.White else Color.White.copy(alpha = 0.7f),
            style = MaterialTheme.typography.labelSmall,
        )
    }
}

/** Accessibility label for a thumbnail cell; also what E2E tests look up. */
fun thumbnailLabel(page: Int): String = "ページ ${page + 1}"

private val CELL_MIN_WIDTH = 144.dp
