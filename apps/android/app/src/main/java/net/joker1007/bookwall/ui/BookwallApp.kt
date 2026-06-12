package net.joker1007.bookwall.ui

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.opds.numericId
import net.joker1007.bookwall.feature.catalog.CatalogScreen
import net.joker1007.bookwall.feature.catalog.CatalogViewModel
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
    // The host owns the format branching the readers can't do (navigate to the
    // image reader vs. download + launch the EPUB activity).
    LaunchedEffect(Unit) {
        launcher.openRequests.collect { req ->
            openBook(navController, launcher, req.serverId, req.book)
        }
    }
    val foliateLaunch by launcher.foliateLaunch.collectAsState()
    LaunchedEffect(foliateLaunch) {
        foliateLaunch?.let { l ->
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
                onOpenReader = { book -> navController.navigate(Destinations.reader(serverId, book)) },
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
            ),
        ) {
            ReaderScreen(onBack = { navController.popBackStack() })
        }
    }
}

/**
 * Opens [book] in the appropriate reader. Image books (PSE) are a Compose
 * destination; EPUBs download and launch the foliate activity. When triggered
 * from the image reader, the current reader entry is replaced so Back returns to
 * the catalog, not the previous book (mirrors the web reader's history replace).
 */
private fun openBook(
    navController: NavController,
    launcher: BookLauncherViewModel,
    serverId: Long,
    book: OpdsEntry.Book,
) {
    val onReader = navController.currentDestination?.route == Destinations.READER
    if (book.pse != null) {
        navController.navigate(Destinations.reader(serverId, book)) {
            if (onReader) popUpTo(Destinations.READER) { inclusive = true }
        }
    } else {
        if (onReader) navController.popBackStack(Destinations.READER, inclusive = true)
        launcher.openEpub(serverId, book)
    }
}

object Destinations {
    const val SERVERS = "servers"
    const val SERVER_FORM = "server_form?serverId={serverId}"
    const val CATALOG = "catalog?serverId={serverId}&feedUrl={feedUrl}"
    const val READER =
        "reader?serverId={serverId}&bookId={bookId}&pageCount={pageCount}" +
            "&initialPage={initialPage}&title={title}&pseTemplate={pseTemplate}"

    fun serverForm(serverId: Long = AddEditServerViewModel.NEW_SERVER_ID): String =
        "server_form?serverId=$serverId"

    fun catalog(serverId: Long, feedUrl: String = ""): String =
        "catalog?serverId=$serverId&feedUrl=${Uri.encode(feedUrl)}"

    fun reader(serverId: Long, book: net.joker1007.bookwall.data.opds.OpdsEntry.Book): String {
        val pse = book.pse
        val bookId = book.numericId ?: 0L
        val pageCount = pse?.pageCount ?: 0
        val initialPage = ((pse?.lastRead ?: 1) - 1).coerceAtLeast(0)
        val template = Uri.encode(pse?.streamHrefTemplate.orEmpty())
        val title = Uri.encode(book.title)
        return "reader?serverId=$serverId&bookId=$bookId&pageCount=$pageCount" +
            "&initialPage=$initialPage&title=$title&pseTemplate=$template"
    }
}
