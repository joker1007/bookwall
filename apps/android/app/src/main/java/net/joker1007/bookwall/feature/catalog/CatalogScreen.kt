package net.joker1007.bookwall.feature.catalog

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.feature.foliatereader.FoliateReaderActivity

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CatalogScreen(
    onOpenFeed: (feedUrl: String) -> Unit,
    onOpenReader: (OpdsEntry.Book) -> Unit,
    onBack: () -> Unit,
    viewModel: CatalogViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val selectedBook by viewModel.selectedBook.collectAsState()
    val selectedLocalPage by viewModel.selectedLocalPage.collectAsState()
    val selectedEpubProgress by viewModel.selectedEpubProgress.collectAsState()
    val imageLoader by viewModel.imageLoader.collectAsState()
    val foliateLaunch by viewModel.foliateLaunch.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(foliateLaunch) {
        foliateLaunch?.let { launch ->
            context.startActivity(
                FoliateReaderActivity.intent(
                    context,
                    serverId = launch.serverId,
                    bookId = launch.bookId,
                    title = launch.title,
                    filePath = launch.filePath,
                ),
            )
            viewModel.consumeFoliateLaunch()
        }
    }

    Scaffold(
        modifier = Modifier.testTag(CatalogTags.ROOT),
        topBar = {
            TopAppBar(
                title = { Text(state.title.ifEmpty { "カタログ" }, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
                actions = {
                    if (state.books.isNotEmpty()) {
                        ViewModeAction(state.viewMode, viewModel::setViewMode)
                        SortAction(state.sort, state.sortDirection, viewModel::setSort)
                    }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                state.loading -> CircularProgressIndicator(
                    modifier = Modifier
                        .align(Alignment.Center)
                        .testTag(CatalogTags.LOADING),
                )
                state.error != null -> ErrorState(state.error!!, viewModel::retry)
                else -> CatalogContent(
                    state = state,
                    imageLoader = imageLoader,
                    resolve = viewModel::resolve,
                    onOpenFeed = { href -> viewModel.resolve(href)?.let(onOpenFeed) },
                    onBookClick = viewModel::selectBook,
                )
            }
        }
    }

    selectedBook?.let { book ->
        ModalBottomSheet(onDismissRequest = viewModel::dismissBook) {
            BookDetail(
                book = book,
                localCurrentPage = selectedLocalPage,
                epubProgress = selectedEpubProgress,
                onRead = { selected ->
                    viewModel.dismissBook()
                    if (selected.pse != null) onOpenReader(selected) else viewModel.openEpub(selected)
                },
                modifier = Modifier.testTag(CatalogTags.DETAIL_SHEET),
            )
        }
    }
}

@Composable
private fun CatalogContent(
    state: CatalogUiState,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onOpenFeed: (String) -> Unit,
    onBookClick: (OpdsEntry.Book) -> Unit,
) {
    val columns = if (state.viewMode == ViewMode.GRID) GridCells.Adaptive(120.dp) else GridCells.Fixed(1)
    LazyVerticalGrid(
        columns = columns,
        modifier = Modifier
            .fillMaxSize()
            .testTag(CatalogTags.LIST),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(state.navEntries, span = { GridItemSpan(maxLineSpan) }) { entry ->
            ListItem(
                headlineContent = { Text(entry.title) },
                supportingContent = entry.summary?.let { { Text(it) } },
                modifier = Modifier.clickable { onOpenFeed(entry.href) },
            )
        }
        items(state.books, key = { it.id }) { book ->
            if (state.viewMode == ViewMode.GRID) {
                BookGridCell(book, imageLoader, resolve, onBookClick)
            } else {
                BookListRow(book, imageLoader, resolve, onBookClick)
            }
        }
    }
}

@Composable
private fun BookGridCell(
    book: OpdsEntry.Book,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onClick: (OpdsEntry.Book) -> Unit,
) {
    Column(modifier = Modifier.clickable { onClick(book) }) {
        Cover(
            url = resolve(book.thumbnailHref ?: book.imageHref),
            imageLoader = imageLoader,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f),
        )
        Text(
            text = book.title,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun BookListRow(
    book: OpdsEntry.Book,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onClick: (OpdsEntry.Book) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick(book) },
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Cover(
            url = resolve(book.thumbnailHref ?: book.imageHref),
            imageLoader = imageLoader,
            modifier = Modifier
                .size(width = 60.dp, height = 86.dp),
        )
        Column(modifier = Modifier.padding(vertical = 4.dp)) {
            Text(book.title, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (book.authors.isNotEmpty()) {
                Text(
                    book.authors.joinToString(", "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (book.tags.isNotEmpty()) {
                Text(
                    book.tags.joinToString(" · "),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun Cover(url: String?, imageLoader: coil3.ImageLoader?, modifier: Modifier = Modifier) {
    if (url != null && imageLoader != null) {
        AsyncImage(
            model = url,
            contentDescription = null,
            imageLoader = imageLoader,
            modifier = modifier,
        )
    } else {
        Box(modifier = modifier.then(Modifier.fillMaxWidth()))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ViewModeAction(mode: ViewMode, onChange: (ViewMode) -> Unit) {
    IconButton(
        onClick = { onChange(if (mode == ViewMode.GRID) ViewMode.LIST else ViewMode.GRID) },
        modifier = Modifier.testTag(CatalogTags.VIEW_MODE_TOGGLE),
    ) {
        if (mode == ViewMode.GRID) {
            Icon(Icons.AutoMirrored.Filled.List, contentDescription = "リスト表示")
        } else {
            Icon(Icons.Default.GridView, contentDescription = "グリッド表示")
        }
    }
}

private val SORT_OPTIONS = listOf(
    Triple("タイトル順 (昇順)", BookSort.TITLE, SortDirection.ASC),
    Triple("タイトル順 (降順)", BookSort.TITLE, SortDirection.DESC),
    Triple("著者順 (昇順)", BookSort.AUTHOR, SortDirection.ASC),
    Triple("著者順 (降順)", BookSort.AUTHOR, SortDirection.DESC),
    Triple("登録日順 (新しい順)", BookSort.ADDED, SortDirection.DESC),
    Triple("登録日順 (古い順)", BookSort.ADDED, SortDirection.ASC),
)

@Composable
private fun SortAction(
    sort: BookSort,
    direction: SortDirection,
    onSort: (BookSort, SortDirection) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    IconButton(onClick = { expanded = true }, modifier = Modifier.testTag(CatalogTags.SORT_BUTTON)) {
        Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = "並び替え")
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        SORT_OPTIONS.forEach { (label, optSort, optDir) ->
            DropdownMenuItem(
                text = { Text(label) },
                onClick = { onSort(optSort, optDir); expanded = false },
                trailingIcon = if (optSort == sort && optDir == direction) {
                    { Icon(Icons.Default.Check, contentDescription = null) }
                } else {
                    null
                },
            )
        }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(message, modifier = Modifier.testTag(CatalogTags.ERROR))
        Button(onClick = onRetry, modifier = Modifier.padding(top = 12.dp)) { Text("再試行") }
    }
}

object CatalogTags {
    const val ROOT = "catalog_root"
    const val LIST = "catalog_list"
    const val LOADING = "catalog_loading"
    const val ERROR = "catalog_error"
    const val VIEW_MODE_TOGGLE = "catalog_view_mode_toggle"
    const val SORT_BUTTON = "catalog_sort_button"
    const val DETAIL_SHEET = "catalog_detail_sheet"
}
