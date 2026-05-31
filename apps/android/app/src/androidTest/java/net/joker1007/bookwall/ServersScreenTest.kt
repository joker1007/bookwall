package net.joker1007.bookwall

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import net.joker1007.bookwall.robot.onServersScreen
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ServersScreenTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun showsEmptyStateOnLaunch() {
        composeRule.onServersScreen {
            assertScreenDisplayed()
            assertEmptyStateShown()
        }
    }
}
