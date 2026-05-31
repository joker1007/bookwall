package net.joker1007.bookwall.robot

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import net.joker1007.bookwall.feature.servers.ServerFormTags

/** Robot driving the add/edit OPDS server form. */
class ServerFormRobot(composeRule: ComposeTestRule) : ComposeRobot(composeRule) {

    fun assertDisplayed() = apply {
        composeRule.onNodeWithTag(ServerFormTags.ROOT).assertIsDisplayed()
    }

    fun enterName(value: String) = apply {
        composeRule.onNodeWithTag(ServerFormTags.NAME).performTextInput(value)
    }

    fun enterUrl(value: String) = apply {
        composeRule.onNodeWithTag(ServerFormTags.URL).performTextInput(value)
    }

    fun save() = apply {
        composeRule.onNodeWithTag(ServerFormTags.SAVE_BUTTON).performClick()
    }

    fun testConnection() = apply {
        composeRule.onNodeWithTag(ServerFormTags.TEST_BUTTON).performClick()
    }

    fun assertTestResultShown() = apply {
        composeRule.onNodeWithTag(ServerFormTags.TEST_RESULT).assertIsDisplayed()
    }
}

fun ComposeTestRule.onServerForm(block: ServerFormRobot.() -> Unit): ServerFormRobot =
    ServerFormRobot(this).apply(block)
