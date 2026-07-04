package net.joker1007.bookwall.ui

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.feature.catalog.CatalogScreen
import net.joker1007.bookwall.feature.catalog.CatalogViewModel
import net.joker1007.bookwall.feature.downloads.DownloadedBooksScreen
import net.joker1007.bookwall.feature.settings.SettingsScreen
import net.joker1007.bookwall.feature.foliatereader.FoliateReaderActivity
import net.joker1007.bookwall.feature.reader.ReaderScreen
import net.joker1007.bookwall.feature.reader.ReaderViewModel
import net.joker1007.bookwall.feature.servers.AddEditServerScreen
import net.joker1007.bookwall.feature.servers.AddEditServerViewModel
import net.joker1007.bookwall.feature.servers.ServersScreen

/**
 * Root of the Compose UI. Holds the app-wide [NavHost]; feature screens are
 * registered as destinations here.
 */
@Composable
fun BookwallApp(launcher: BookLauncherViewModel = hiltViewModel()) {
    val navController = rememberNavController()
    val context = LocalContext.current

    // Roll-over: a reader reaching the end of a book asks to open the next one.
    // The launcher owns the format/cache branching; this host only navigates.
    LaunchedEffect(Unit) {
        launcher.openRequests.collect { req -> launcher.open(req.serverId, req.book) }
    }
    // Image reader route (streaming or cached local file). When triggered from
    // the reader itself, replace the entry so Back returns to the catalog, not
    // the previous book (mirrors the web reader's history replace).
    val readerRoute by launcher.readerRoute.collectAsState()
    LaunchedEffect(readerRoute) {
        readerRoute?.let { route ->
            val onReader = navController.currentDestination?.route == Destinations.READER
            navController.navigate(route) {
                if (onReader) popUpTo(Destinations.READER) { inclusive = true }
            }
            launcher.consumeReaderRoute()
        }
    }
    val foliateLaunch by launcher.foliateLaunch.collectAsState()
    LaunchedEffect(foliateLaunch) {
        foliateLaunch?.let { l ->
            if (navController.currentDestination?.route == Destinations.READER) {
                navController.popBackStack(Destinations.READER, inclusive = true)
            }
            context.startActivity(
                FoliateReaderActivity.intent(context, l.serverId, l.bookId, l.title, l.filePath),
            )
            launcher.consumeFoliateLaunch()
        }
    }

    NavHost(navController = navController, startDestination = Destinations.SERVERS) {
        composable(Destinations.SERVERS) {
            ServersScreen(
                onOpenServer = { id -> navController.navigate(Destinations.catalog(id)) },
                onAddServer = { navController.navigate(Destinations.serverForm()) },
                onEditServer = { id -> navController.navigate(Destinations.serverForm(id)) },
                onOpenDownloads = { navController.navigate(Destinations.DOWNLOADS) },
                onOpenSettings = { navController.navigate(Destinations.SETTINGS) },
            )
        }
        composable(Destinations.SETTINGS) {
            SettingsScreen(onBack = { navController.popBackStack() })
        }
        composable(Destinations.DOWNLOADS) {
            DownloadedBooksScreen(
                onOpenBook = { entity -> launcher.openCached(entity) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = Destinations.SERVER_FORM,
            arguments = listOf(
                navArgument(AddEditServerViewModel.ARG_SERVER_ID) {
                    type = NavType.LongType
                    defaultValue = AddEditServerViewModel.NEW_SERVER_ID
                },
            ),
        ) {
            AddEditServerScreen(
                onSaved = { navController.popBackStack() },
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = Destinations.CATALOG,
            arguments = listOf(
                navArgument(CatalogViewModel.ARG_SERVER_ID) { type = NavType.LongType },
                navArgument(CatalogViewModel.ARG_FEED_URL) {
                    type = NavType.StringType
                    defaultValue = ""
                },
            ),
        ) { entry ->
            val serverId = entry.arguments?.getLong(CatalogViewModel.ARG_SERVER_ID) ?: 0L
            CatalogScreen(
                onOpenFeed = { feedUrl -> navController.navigate(Destinations.catalog(serverId, feedUrl)) },
                onOpenBook = { book -> launcher.open(serverId, book) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = Destinations.READER,
            arguments = listOf(
                navArgument(ReaderViewModel.ARG_SERVER_ID) { type = NavType.LongType },
                navArgument(ReaderViewModel.ARG_BOOK_ID) { type = NavType.LongType },
                navArgument(ReaderViewModel.ARG_PAGE_COUNT) { type = NavType.IntType },
                navArgument(ReaderViewModel.ARG_INITIAL_PAGE) { type = NavType.IntType; defaultValue = 0 },
                navArgument(ReaderViewModel.ARG_TITLE) { type = NavType.StringType; defaultValue = "" },
                navArgument(ReaderViewModel.ARG_PSE_TEMPLATE) { type = NavType.StringType; defaultValue = "" },
                navArgument(ReaderViewModel.ARG_LOCAL_PATH) { type = NavType.StringType; defaultValue = "" },
            ),
        ) {
            ReaderScreen(onBack = { navController.popBackStack() })
        }
    }
}

object Destinations {
    const val SERVERS = "servers"
    const val DOWNLOADS = "downloads"
    const val SETTINGS = "settings"
    const val SERVER_FORM = "server_form?serverId={serverId}"
    const val CATALOG = "catalog?serverId={serverId}&feedUrl={feedUrl}"
    const val READER =
        "reader?serverId={serverId}&bookId={bookId}&pageCount={pageCount}" +
            "&initialPage={initialPage}&title={title}&pseTemplate={pseTemplate}&localPath={localPath}"

    fun serverForm(serverId: Long = AddEditServerViewModel.NEW_SERVER_ID): String =
        "server_form?serverId=$serverId"

    fun catalog(serverId: Long, feedUrl: String = ""): String =
        "catalog?serverId=$serverId&feedUrl=${Uri.encode(feedUrl)}"

    fun reader(
        serverId: Long,
        book: net.joker1007.bookwall.data.opds.OpdsEntry.Book,
        localPath: String? = null,
    ): String {
        val pse = book.pse
        val bookId = book.numericId ?: 0L
        val pageCount = pse?.pageCount ?: 0
        val initialPage = ((pse?.lastRead ?: 1) - 1).coerceAtLeast(0)
        val template = Uri.encode(pse?.streamHrefTemplate.orEmpty())
        val title = Uri.encode(book.title)
        return "reader?serverId=$serverId&bookId=$bookId&pageCount=$pageCount" +
            "&initialPage=$initialPage&title=$title&pseTemplate=$template" +
            "&localPath=${Uri.encode(localPath.orEmpty())}"
    }

    /** Reader route for a cached book opened offline (no feed metadata). */
    fun cachedReader(serverId: Long, bookId: Long, pageCount: Int, title: String, localPath: String): String =
        "reader?serverId=$serverId&bookId=$bookId&pageCount=$pageCount" +
            "&initialPage=0&title=${Uri.encode(title)}&pseTemplate=&localPath=${Uri.encode(localPath)}"
}
