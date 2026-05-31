package net.joker1007.bookwall.robot

import androidx.compose.ui.test.junit4.ComposeTestRule

/**
 * Base class for Robot-pattern screen drivers. Each screen Robot exposes
 * high-level actions and assertions so tests read as a behavioral script.
 */
abstract class ComposeRobot(protected val composeRule: ComposeTestRule)
