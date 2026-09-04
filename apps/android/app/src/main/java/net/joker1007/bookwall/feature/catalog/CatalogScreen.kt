package net.joker1007.bookwall.feature.catalog

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DownloadDone
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import coil3.compose.AsyncImage
import net.joker1007.bookwall.data.db.CachedBookEntity
import net.joker1007.bookwall.data.db.CachedBookStatus
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.OpdsFacet
import net.joker1007.bookwall.data.opds.numericId

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CatalogScreen(
    onOpenFeed: (feedUrl: String) -> Unit,
    onOpenBook: (OpdsEntry.Book) -> Unit,
    onBack: () -> Unit,
    viewModel: CatalogViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val cacheStates by viewModel.cacheStates.collectAsState()
    val selectedBook by viewModel.selectedBook.collectAsState()
    val selectedLocalPage by viewModel.selectedLocalPage.collectAsState()
    val selectedEpubProgress by viewModel.selectedEpubProgress.collectAsState()
    val imageLoader by viewModel.imageLoader.collectAsState()
    var filterActive by remember { mutableStateOf(false) }
    var facetSheetOpen by remember { mutableStateOf(false) }

    Scaffold(
        modifier = Modifier.testTag(CatalogTags.ROOT),
        topBar = {
            TopAppBar(
                title = {
                    if (filterActive) {
                        FilterField(
                            query = state.filterQuery,
                            onQueryChange = viewModel::setFilter,
                        )
                    } else {
                        Text(state.title.ifEmpty { "カタログ" }, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                },
                navigationIcon = {
                    IconButton(
                        onClick = {
                            if (filterActive) {
                                filterActive = false
                                viewModel.setFilter("")
                            } else {
                                onBack()
                            }
                        },
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = if (filterActive) "絞り込みを閉じる" else "戻る")
                    }
                },
                actions = {
                    val hasEntries = state.books.isNotEmpty() || state.navEntries.isNotEmpty()
                    if ((hasEntries || state.filterQuery.isNotEmpty()) && !filterActive) {
                        FilterAction { filterActive = true }
                    }
                    if (state.facets.isNotEmpty() && !filterActive) {
                        FacetAction(active = state.hasActiveFacet) { facetSheetOpen = true }
                    }
                    if (hasEntries && !filterActive) {
                        ViewModeAction(state.viewMode, viewModel::setViewMode)
                        // Navigation feeds only have a title axis; books get all axes.
                        SortAction(state.sort, state.sortDirection, state.books.isNotEmpty(), viewModel::setSort)
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
                state.navEntries.isEmpty() && state.books.isEmpty() && state.filterQuery.isNotBlank() ->
                    Text(
                        "該当するエントリがありません",
                        modifier = Modifier
                            .align(Alignment.Center)
                            .testTag(CatalogTags.FILTER_EMPTY),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                else -> CatalogContent(
                    state = state,
                    cacheStates = cacheStates,
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
                cacheStatus = book.numericId?.let { cacheStates[it] },
                onRead = { selected ->
                    viewModel.dismissBook()
                    onOpenBook(selected)
                },
                onDownload = viewModel::downloadBook,
                onRemoveCache = viewModel::removeCache,
                onOpenSeries = { href ->
                    viewModel.dismissBook()
                    viewModel.resolve(href)?.let(onOpenFeed)
                },
                modifier = Modifier.testTag(CatalogTags.DETAIL_SHEET),
            )
        }
    }

    if (facetSheetOpen) {
        ModalBottomSheet(onDismissRequest = { facetSheetOpen = false }) {
            FacetSheet(
                facets = state.facets,
                hasActiveFacet = state.hasActiveFacet,
                onSelect = { facet ->
                    viewModel.selectFacet(facet)
                    facetSheetOpen = false
                },
                onClear = {
                    viewModel.clearFacets()
                    facetSheetOpen = false
                },
            )
        }
    }
}

@Composable
private fun CatalogContent(
    state: CatalogUiState,
    cacheStates: Map<Long, CachedBookEntity>,
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
        items(state.navEntries, key = { it.id }) { entry ->
            if (state.viewMode == ViewMode.GRID) {
                NavGridCell(entry, imageLoader, resolve, onOpenFeed)
            } else {
                NavListRow(entry, imageLoader, resolve, onOpenFeed)
            }
        }
        items(state.books, key = { it.id }) { book ->
            val cache = book.numericId?.let { cacheStates[it] }
            if (state.viewMode == ViewMode.GRID) {
                BookGridCell(book, cache, imageLoader, resolve, onBookClick)
            } else {
                BookListRow(book, cache, imageLoader, resolve, onBookClick)
            }
        }
    }
}

@Composable
private fun BookGridCell(
    book: OpdsEntry.Book,
    cache: CachedBookEntity?,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onClick: (OpdsEntry.Book) -> Unit,
) {
    Column(modifier = Modifier.clickable { onClick(book) }) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f),
        ) {
            Cover(
                url = resolve(book.thumbnailHref ?: book.imageHref),
                imageLoader = imageLoader,
                modifier = Modifier.fillMaxSize(),
            )
            CacheBadge(cache, modifier = Modifier.align(Alignment.TopEnd))
        }
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
    cache: CachedBookEntity?,
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
        Box(modifier = Modifier.size(width = 60.dp, height = 86.dp)) {
            Cover(
                url = resolve(book.thumbnailHref ?: book.imageHref),
                imageLoader = imageLoader,
                modifier = Modifier.fillMaxSize(),
            )
            CacheBadge(cache, modifier = Modifier.align(Alignment.TopEnd))
        }
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
private fun NavGridCell(
    entry: OpdsEntry.Navigation,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onClick: (String) -> Unit,
) {
    Column(modifier = Modifier.clickable { onClick(entry.href) }) {
        NavCover(
            url = resolve(entry.thumbnailHref ?: entry.imageHref),
            imageLoader = imageLoader,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f),
        )
        Text(
            text = entry.title,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun NavListRow(
    entry: OpdsEntry.Navigation,
    imageLoader: coil3.ImageLoader?,
    resolve: (String?) -> String?,
    onClick: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick(entry.href) },
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        NavCover(
            url = resolve(entry.thumbnailHref ?: entry.imageHref),
            imageLoader = imageLoader,
            modifier = Modifier.size(width = 60.dp, height = 86.dp),
        )
        Column(modifier = Modifier.padding(vertical = 4.dp)) {
            Text(entry.title, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
            entry.summary?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Cover slot for navigation entries: the supplied image, or a folder icon when none. */
@Composable
private fun NavCover(url: String?, imageLoader: coil3.ImageLoader?, modifier: Modifier = Modifier) {
    if (url != null && imageLoader != null) {
        AsyncImage(model = url, contentDescription = null, imageLoader = imageLoader, modifier = modifier)
    } else {
        Box(
            modifier = modifier.background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Folder,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxSize(0.4f),
            )
        }
    }
}

/** Cache state overlay on a cover: done check, download progress, or failure. */
@Composable
private fun CacheBadge(cache: CachedBookEntity?, modifier: Modifier = Modifier) {
    if (cache == null) return
    Box(
        modifier = modifier
            .padding(4.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.85f))
            .padding(2.dp)
            .testTag(CatalogTags.CACHE_BADGE),
        contentAlignment = Alignment.Center,
    ) {
        when (cache.status) {
            CachedBookStatus.COMPLETED -> Icon(
                Icons.Filled.DownloadDone,
                contentDescription = "ダウンロード済み",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(16.dp),
            )
            CachedBookStatus.PENDING, CachedBookStatus.DOWNLOADING -> {
                val progress = if (cache.totalBytes > 0) {
                    cache.downloadedBytes.toFloat() / cache.totalBytes.toFloat()
                } else {
                    null
                }
                if (progress != null && cache.status == CachedBookStatus.DOWNLOADING) {
                    CircularProgressIndicator(
                        progress = { progress },
                        strokeWidth = 2.dp,
                        modifier = Modifier.size(16.dp),
                    )
                } else {
                    CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                }
            }
            CachedBookStatus.FAILED -> Icon(
                Icons.Filled.ErrorOutline,
                contentDescription = "ダウンロード失敗",
                tint = MaterialTheme.colorScheme.error,
                modifier = Modifier.size(16.dp),
            )
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

@Composable
private fun FilterAction(onActivate: () -> Unit) {
    IconButton(onClick = onActivate, modifier = Modifier.testTag(CatalogTags.FILTER_TOGGLE)) {
        Icon(Icons.Default.Search, contentDescription = "絞り込み")
    }
}

@Composable
private fun FacetAction(active: Boolean, onActivate: () -> Unit) {
    IconButton(onClick = onActivate, modifier = Modifier.testTag(CatalogTags.FACET_TOGGLE)) {
        BadgedBox(badge = { if (active) Badge() }) {
            Icon(Icons.Default.FilterList, contentDescription = "Facet で絞り込み")
        }
    }
}

@Composable
private fun FacetSheet(
    facets: List<OpdsFacet>,
    hasActiveFacet: Boolean,
    onSelect: (OpdsFacet) -> Unit,
    onClear: () -> Unit,
) {
    val groups = remember(facets) { facets.groupBy { it.group } }
    Column(modifier = Modifier.testTag(CatalogTags.FACET_SHEET)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("絞り込み", style = MaterialTheme.typography.titleMedium)
            TextButton(
                onClick = onClear,
                enabled = hasActiveFacet,
                modifier = Modifier.testTag(CatalogTags.FACET_CLEAR),
            ) {
                Text("クリア")
            }
        }
        LazyColumn(modifier = Modifier.fillMaxWidth()) {
            groups.forEach { (group, items) ->
                if (group != null) {
                    item(key = "header_$group") {
                        Text(
                            text = group,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(start = 16.dp, top = 12.dp, bottom = 4.dp),
                        )
                    }
                }
                items(items, key = { "${it.group}:${it.title}" }) { facet ->
                    FacetRow(facet, onSelect)
                }
            }
        }
    }
}

@Composable
private fun FacetRow(facet: OpdsFacet, onSelect: (OpdsFacet) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect(facet) }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        RadioButton(selected = facet.active, onClick = { onSelect(facet) })
        Text(
            text = facet.title ?: "",
            style = MaterialTheme.typography.bodyLarge,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        facet.count?.let {
            Text(
                text = it.toString(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun FilterField(query: String, onQueryChange: (String) -> Unit) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    TextField(
        value = query,
        onValueChange = onQueryChange,
        singleLine = true,
        placeholder = { Text("絞り込み") },
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .focusRequester(focusRequester)
            .testTag(CatalogTags.FILTER_FIELD),
    )
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

private val TITLE_SORT_OPTIONS = listOf(
    Triple("タイトル順 (昇順)", BookSort.TITLE, SortDirection.ASC),
    Triple("タイトル順 (降順)", BookSort.TITLE, SortDirection.DESC),
)

private val BOOK_SORT_OPTIONS = listOf(
    Triple("著者順 (昇順)", BookSort.AUTHOR, SortDirection.ASC),
    Triple("著者順 (降順)", BookSort.AUTHOR, SortDirection.DESC),
    Triple("登録日順 (新しい順)", BookSort.ADDED, SortDirection.DESC),
    Triple("登録日順 (古い順)", BookSort.ADDED, SortDirection.ASC),
)

@Composable
private fun SortAction(
    sort: BookSort,
    direction: SortDirection,
    showAllAxes: Boolean,
    onSort: (BookSort, SortDirection) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    // Navigation feeds only sort by title; book feeds add author / added-date.
    val options = if (showAllAxes) TITLE_SORT_OPTIONS + BOOK_SORT_OPTIONS else TITLE_SORT_OPTIONS
    IconButton(onClick = { expanded = true }, modifier = Modifier.testTag(CatalogTags.SORT_BUTTON)) {
        Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = "並び替え")
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        options.forEach { (label, optSort, optDir) ->
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
    const val FILTER_TOGGLE = "catalog_filter_toggle"
    const val FILTER_FIELD = "catalog_filter_field"
    const val FILTER_EMPTY = "catalog_filter_empty"
    const val FACET_TOGGLE = "catalog_facet_toggle"
    const val FACET_SHEET = "catalog_facet_sheet"
    const val FACET_CLEAR = "catalog_facet_clear"
    const val CACHE_BADGE = "catalog_cache_badge"
}
