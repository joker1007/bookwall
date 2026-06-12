package net.joker1007.bookwall.robot

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import net.joker1007.bookwall.feature.reader.ReaderTags
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

    fun assertNextBookDialogShown() = apply {
        composeRule.onNodeWithTag(NextBookDialogTags.ROOT).assertIsDisplayed()
    }

    fun confirmNextBook() = apply {
        composeRule.onNodeWithTag(NextBookDialogTags.CONFIRM).performClick()
    }
}

fun ComposeTestRule.onReaderScreen(block: ReaderRobot.() -> Unit): ReaderRobot =
    ReaderRobot(this).apply(block)
