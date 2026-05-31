package net.joker1007.bookwall.ui

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
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
    }
}

object Destinations {
    const val SERVERS = "servers"
    const val SERVER_FORM = "server_form?serverId={serverId}"

    fun serverForm(serverId: Long = AddEditServerViewModel.NEW_SERVER_ID): String =
        "server_form?serverId=$serverId"
}
