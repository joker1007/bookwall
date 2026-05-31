package net.joker1007.bookwall.ui

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import net.joker1007.bookwall.feature.catalog.CatalogScreen
import net.joker1007.bookwall.feature.catalog.CatalogViewModel
import net.joker1007.bookwall.feature.servers.AddEditServerScreen
import net.joker1007.bookwall.feature.servers.AddEditServerViewModel
import net.joker1007.bookwall.feature.servers.ServersScreen

/**
 * Root of the Compose UI. Holds the app-wide [NavHost]; feature screens are
 * registered as destinations here.
 */
@Composable
fun BookwallApp() {
    val navController = rememberNavController()
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
                onBack = { navController.popBackStack() },
            )
        }
    }
}

object Destinations {
    const val SERVERS = "servers"
    const val SERVER_FORM = "server_form?serverId={serverId}"
    const val CATALOG = "catalog?serverId={serverId}&feedUrl={feedUrl}"

    fun serverForm(serverId: Long = AddEditServerViewModel.NEW_SERVER_ID): String =
        "server_form?serverId=$serverId"

    fun catalog(serverId: Long, feedUrl: String = ""): String =
        "catalog?serverId=$serverId&feedUrl=${Uri.encode(feedUrl)}"
}
