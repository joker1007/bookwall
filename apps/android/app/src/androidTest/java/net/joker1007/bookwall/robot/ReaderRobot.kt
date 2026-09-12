package net.joker1007.bookwall.robot

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.pinch
import androidx.compose.ui.test.swipeLeft
import net.joker1007.bookwall.data.reader.SpreadMode
import net.joker1007.bookwall.feature.reader.ReaderTags
import net.joker1007.bookwall.feature.reader.ReaderZoomScaleKey
import net.joker1007.bookwall.feature.reader.thumbnailLabel
import net.joker1007.bookwall.ui.NextBookDialogTags

/** Robot driving the image reader screen. */
class ReaderRobot(composeRule: ComposeTestRule) : ComposeRobot(composeRule) {

    fun assertDisplayed() = apply {
        composeRule.onNodeWithTag(ReaderTags.ROOT).assertIsDisplayed()
    }

    fun assertScrubberDisplayed() = apply {
        composeRule.onNodeWithTag(ReaderTags.SCRUBBER).assertIsDisplayed()
    }

    /** Taps the left third. With the default RTL direction this advances a page. */
    fun tapLeftZone() = apply {
        composeRule.onNodeWithTag(ReaderTags.PAGER).performTouchInput {
            click(Offset(width * 0.1f, height * 0.5f))
        }
    }

    /** Taps the center third, which toggles the menu. */
    fun tapCenterZone() = apply {
        composeRule.onNodeWithTag(ReaderTags.PAGER).performTouchInput {
            click(Offset(width * 0.5f, height * 0.5f))
        }
    }

    /** Spreads two fingers apart on the current page to zoom in. */
    fun pinchToZoom() = apply {
        composeRule.onNodeWithTag(ReaderTags.PAGER).performTouchInput {
            pinch(
                start0 = Offset(width * 0.45f, height * 0.5f),
                end0 = Offset(width * 0.15f, height * 0.5f),
                start1 = Offset(width * 0.55f, height * 0.5f),
                end1 = Offset(width * 0.85f, height * 0.5f),
            )
        }
    }

    /** Swipes left, which pages forward when not zoomed. */
    fun swipePage() = apply {
        composeRule.onNodeWithTag(ReaderTags.PAGER).performTouchInput { swipeLeft() }
    }

    fun assertZoomed() = apply {
        composeRule.waitUntil(ZOOM_TIMEOUT) { (currentZoomScale() ?: 1f) > 1f }
    }

    fun assertNotZoomed() = apply {
        composeRule.waitUntil(ZOOM_TIMEOUT) { (currentZoomScale() ?: 1f) <= 1f + ZOOM_EPS }
    }

    /** Reads the current page's zoom factor exposed via semantics, or null if absent. */
    private fun currentZoomScale(): Float? {
        val node = composeRule.onAllNodesWithTag(ReaderTags.ZOOM_LAYER)
            .fetchSemanticsNodes().firstOrNull() ?: return null
        return if (node.config.contains(ReaderZoomScaleKey)) node.config[ReaderZoomScaleKey] else null
    }

    fun openSettings() = apply {
        composeRule.onNodeWithTag(ReaderTags.SETTINGS_BUTTON).performClick()
        composeRule.onNodeWithTag(ReaderTags.SETTINGS_SHEET).assertIsDisplayed()
    }

    fun selectSpreadMode(mode: SpreadMode) = apply {
        composeRule.onNodeWithTag(ReaderTags.spreadModeTag(mode)).performClick()
    }

    /** The offset button is only offered while pages are actually paired. */
    fun assertSpreadActive(active: Boolean) = apply {
        composeRule.waitUntil(ZOOM_TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.OFFSET_BUTTON).fetchSemanticsNodes().isNotEmpty() == active
        }
    }

    fun openThumbnails() = apply {
        composeRule.onNodeWithTag(ReaderTags.THUMBNAILS_BUTTON).performClick()
        composeRule.onNodeWithTag(ReaderTags.THUMBNAIL_GRID).assertIsDisplayed()
    }

    // Cells are clickable, so their testTag is merged away; match the
    // contentDescription instead.
    fun clickThumbnail(page: Int) = apply {
        // The overlay root swallows clicks, which merges the grid tag away.
        composeRule.onNodeWithTag(ReaderTags.THUMBNAIL_LIST, useUnmergedTree = true)
            .performScrollToNode(hasContentDescription(thumbnailLabel(page)))
        composeRule.onNodeWithContentDescription(thumbnailLabel(page)).performClick()
    }

    fun closeThumbnails() = apply {
        composeRule.onNodeWithTag(ReaderTags.THUMBNAIL_CLOSE).performClick()
    }

    fun assertThumbnailsHidden() = apply {
        composeRule.waitUntil(ZOOM_TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.THUMBNAIL_GRID).fetchSemanticsNodes().isEmpty()
        }
    }

    /** The scrubber label reads "n / total" while the menu is open. */
    fun assertPageIndicator(text: String) = apply {
        composeRule.waitUntil(ZOOM_TIMEOUT) {
            composeRule.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
        }
    }

    fun assertNextBookDialogShown() = apply {
        composeRule.onNodeWithTag(NextBookDialogTags.ROOT).assertIsDisplayed()
    }

    fun confirmNextBook() = apply {
        composeRule.onNodeWithTag(NextBookDialogTags.CONFIRM).performClick()
    }

    private companion object {
        const val ZOOM_TIMEOUT = 3_000L
        const val ZOOM_EPS = 0.01f
    }
}

fun ComposeTestRule.onReaderScreen(block: ReaderRobot.() -> Unit): ReaderRobot =
    ReaderRobot(this).apply(block)
