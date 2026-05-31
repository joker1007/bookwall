package net.joker1007.bookwall.robot

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import net.joker1007.bookwall.feature.servers.ServersScreenTags

/** Robot driving the OPDS server list screen. */
class ServersRobot(composeRule: ComposeTestRule) : ComposeRobot(composeRule) {

    fun assertScreenDisplayed() = apply {
        composeRule.onNodeWithTag(ServersScreenTags.ROOT).assertIsDisplayed()
    }

    fun assertEmptyStateShown() = apply {
        composeRule.onNodeWithTag(ServersScreenTags.EMPTY_MESSAGE).assertIsDisplayed()
    }
}

fun ComposeTestRule.onServersScreen(block: ServersRobot.() -> Unit): ServersRobot =
    ServersRobot(this).apply(block)
