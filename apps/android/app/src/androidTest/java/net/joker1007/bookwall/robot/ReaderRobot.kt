package net.joker1007.bookwall.robot

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import net.joker1007.bookwall.feature.reader.ReaderTags

/** Robot driving the image reader screen. */
class ReaderRobot(composeRule: ComposeTestRule) : ComposeRobot(composeRule) {

    fun assertDisplayed() = apply {
        composeRule.onNodeWithTag(ReaderTags.ROOT).assertIsDisplayed()
    }

    fun assertScrubberDisplayed() = apply {
        composeRule.onNodeWithTag(ReaderTags.SCRUBBER).assertIsDisplayed()
    }
}

fun ComposeTestRule.onReaderScreen(block: ReaderRobot.() -> Unit): ReaderRobot =
    ReaderRobot(this).apply(block)
