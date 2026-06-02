package net.joker1007.bookwall.robot

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import net.joker1007.bookwall.feature.catalog.CatalogTags

/** Robot driving the OPDS catalog browse screen. */
class CatalogRobot(composeRule: ComposeTestRule) : ComposeRobot(composeRule) {

    fun assertDisplayed() = apply {
        composeRule.onNodeWithTag(CatalogTags.ROOT).assertIsDisplayed()
    }

    fun toggleViewMode() = apply {
        composeRule.onNodeWithTag(CatalogTags.VIEW_MODE_TOGGLE).performClick()
    }

    fun openSortMenu() = apply {
        composeRule.onNodeWithTag(CatalogTags.SORT_BUTTON).performClick()
    }

    fun openFilter() = apply {
        composeRule.onNodeWithTag(CatalogTags.FILTER_TOGGLE).performClick()
    }

    fun typeFilter(query: String) = apply {
        composeRule.onNodeWithTag(CatalogTags.FILTER_FIELD).performTextInput(query)
    }

    fun assertEntryShown(title: String) = apply {
        composeRule.onNodeWithText(title).assertIsDisplayed()
    }

    fun assertEntryAbsent(title: String) = apply {
        composeRule.onAllNodesWithText(title).assertCountEquals(0)
    }
}

fun ComposeTestRule.onCatalogScreen(block: CatalogRobot.() -> Unit): CatalogRobot =
    CatalogRobot(this).apply(block)
