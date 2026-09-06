package net.joker1007.bookwall

import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import net.joker1007.bookwall.data.reader.SpreadMode
import net.joker1007.bookwall.feature.catalog.BookDetailTags
import net.joker1007.bookwall.feature.reader.ReaderTags
import net.joker1007.bookwall.robot.onCatalogScreen
import net.joker1007.bookwall.robot.onReaderScreen
import net.joker1007.bookwall.robot.onServerForm
import net.joker1007.bookwall.robot.onServersScreen
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okio.Buffer
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream

/**
 * The spread setting has three states. AUTO pairs pages only while the window
 * is wider than it is tall, so rotating the device flips it on and off.
 */
@RunWith(AndroidJUnit4::class)
class ReaderSpreadModeTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse = when {
                    request.path == "/opds" -> MockResponse().setResponseCode(200).setBody(FEED)
                    request.path!!.startsWith("/opds/books/1/pages/") ->
                        MockResponse().setResponseCode(200).setBody(Buffer().write(pngBytes()))
                    else -> MockResponse().setResponseCode(404)
                }
            }
            start()
        }
        setOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)
        cleanState()
    }

    @After
    fun tearDown() {
        setOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED)
        cleanState()
        server.shutdown()
    }

    @Test
    fun autoSpreadFollowsOrientation() {
        openReader()
        composeRule.onReaderScreen {
            tapCenterZone()
            openSettings()

            selectSpreadMode(SpreadMode.ON)
            assertSpreadActive(true)

            selectSpreadMode(SpreadMode.OFF)
            assertSpreadActive(false)

            selectSpreadMode(SpreadMode.AUTO)
            assertSpreadActive(false)
        }

        setOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
        composeRule.onReaderScreen { assertSpreadActive(true) }

        setOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)
        composeRule.onReaderScreen { assertSpreadActive(false) }
    }

    private fun openReader() {
        val baseUrl = server.url("/opds").toString()
        composeRule.onServersScreen { clickAdd() }
        composeRule.onServerForm {
            enterName(SERVER_NAME)
            enterUrl(baseUrl)
            save()
        }
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText(SERVER_NAME).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText(SERVER_NAME).performClick()
        composeRule.onCatalogScreen { assertDisplayed() }
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText(BOOK_TITLE).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText(BOOK_TITLE).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.READ_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.READ_BUTTON).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGER).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun setOrientation(orientation: Int) {
        composeRule.activityRule.scenario.onActivity { it.requestedOrientation = orientation }
        composeRule.waitForIdle()
    }

    private fun cleanState() {
        composeRule.waitForIdle()
        repeat(MAX_SERVERS) {
            val deletes = composeRule.onAllNodesWithContentDescription("削除").fetchSemanticsNodes()
            if (deletes.isEmpty()) return
            composeRule.onAllNodesWithContentDescription("削除")[0].performClick()
            composeRule.waitForIdle()
        }
    }

    private companion object {
        const val SERVER_NAME = "SpreadMode E2E"
        const val BOOK_TITLE = "Spread Book"
        const val TIMEOUT = 5_000L
        const val MAX_SERVERS = 20

        fun pngBytes(): ByteArray {
            val bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            return out.toByteArray()
        }

        val FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds" type="application/atom+xml"/>
              <entry>
                <title>Spread Book</title>
                <id>urn:bookwall:book:1</id>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="6"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
