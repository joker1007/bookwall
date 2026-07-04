package net.joker1007.bookwall

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.isToggleable
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.runners.AndroidJUnit4
import net.joker1007.bookwall.feature.servers.ServersScreenTags
import net.joker1007.bookwall.feature.settings.SettingsTags
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SettingsE2ETest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun cacheSettingsPersistAcrossNavigation() {
        composeRule.onNodeWithTag(ServersScreenTags.SETTINGS_BUTTON).performClick()
        composeRule.onNodeWithTag(SettingsTags.ROOT).assertIsDisplayed()

        val wifiSwitch = hasTestTag(SettingsTags.WIFI_ONLY_SWITCH) and isToggleable()
        composeRule.onNode(wifiSwitch).assertIsOn()
        composeRule.onNode(wifiSwitch).performClick()
        composeRule.onNode(wifiSwitch).assertIsOff()

        // Leave and re-enter: the DataStore-backed value must survive.
        Espresso.pressBack()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag(ServersScreenTags.SETTINGS_BUTTON).performClick()
        composeRule.waitForIdle()
        composeRule.onNode(wifiSwitch).assertIsOff()

        // Restore the default so other tests keep Wi-Fi-only semantics.
        composeRule.onNode(wifiSwitch).performClick()
        composeRule.onNode(wifiSwitch).assertIsOn()
    }

    @Test
    fun deleteAllCacheShowsZeroUsage() {
        composeRule.onNodeWithTag(ServersScreenTags.SETTINGS_BUTTON).performClick()
        composeRule.onNodeWithTag(SettingsTags.ROOT).assertIsDisplayed()

        composeRule.onNodeWithTag(SettingsTags.DELETE_ALL_BUTTON).performClick()
        composeRule.onNodeWithTag(SettingsTags.DELETE_ALL_CONFIRM).performClick()
        composeRule.waitForIdle()

        composeRule.onNodeWithTag(SettingsTags.USAGE).assertIsDisplayed()
    }
}
