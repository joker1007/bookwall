package net.joker1007.bookwall.robot

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
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

    // Match the clickable entry cell, not the filter field that may echo the query text.
    fun assertEntryShown(title: String) = apply {
        composeRule.onNode(hasText(title) and hasClickAction()).assertIsDisplayed()
    }

    fun assertEntryAbsent(title: String) = apply {
        composeRule.onAllNodes(hasText(title) and hasClickAction()).assertCountEquals(0)
    }

    fun openFacetSheet() = apply {
        composeRule.onNodeWithTag(CatalogTags.FACET_TOGGLE).performClick()
    }

    fun selectFacet(title: String) = apply {
        composeRule.onNode(hasText(title) and hasAnyAncestor(hasTestTag(CatalogTags.FACET_SHEET))).performClick()
    }

    fun clearFacets() = apply {
        composeRule.onNodeWithTag(CatalogTags.FACET_CLEAR).performClick()
    }
}

fun ComposeTestRule.onCatalogScreen(block: CatalogRobot.() -> Unit): CatalogRobot =
    CatalogRobot(this).apply(block)
