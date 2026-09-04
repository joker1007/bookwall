package net.joker1007.bookwall

import android.graphics.Bitmap
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import net.joker1007.bookwall.feature.catalog.BookDetailTags
import net.joker1007.bookwall.feature.reader.ReaderTags
import net.joker1007.bookwall.robot.onCatalogScreen
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
import java.util.concurrent.TimeUnit

/**
 * The reader shows a per-page spinner while the server is still preparing a
 * streamed page image, and hides it once the page renders.
 */
@RunWith(AndroidJUnit4::class)
class ReaderPageLoadingTest {

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
                        // Simulate slow server-side page extraction.
                        MockResponse().setResponseCode(200)
                            .setBody(Buffer().write(pngBytes()))
                            .setBodyDelay(PAGE_DELAY_MS, TimeUnit.MILLISECONDS)
                    else -> MockResponse().setResponseCode(404)
                }
            }
            start()
        }
        cleanState()
    }

    @After
    fun tearDown() {
        cleanState()
        server.shutdown()
    }

    @Test
    fun showsASpinnerUntilTheStreamedPageArrives() {
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
        // The spinner shows after its grace period while the page is delayed...
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGE_LOADING).fetchSemanticsNodes().isNotEmpty()
        }
        // ...and disappears once the image arrives.
        composeRule.waitUntil(PAGE_DELAY_MS + TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGE_LOADING).fetchSemanticsNodes().isEmpty()
        }
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
        const val SERVER_NAME = "PageLoading E2E"
        const val BOOK_TITLE = "Slow Book"
        const val TIMEOUT = 5_000L
        const val PAGE_DELAY_MS = 2_000L
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
                <title>Slow Book</title>
                <id>urn:bookwall:book:1</id>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="3"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
