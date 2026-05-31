package net.joker1007.bookwall.ui

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
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
            ServersScreen()
        }
    }
}

object Destinations {
    const val SERVERS = "servers"
}
