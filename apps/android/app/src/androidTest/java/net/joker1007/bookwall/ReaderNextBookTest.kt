package net.joker1007.bookwall

import androidx.compose.ui.test.junit4.createAndroidComposeRule
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
import net.joker1007.bookwall.robot.onReaderScreen
import net.joker1007.bookwall.robot.onServerForm
import net.joker1007.bookwall.robot.onServersScreen
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * End-to-end: open the first PSE book from the catalog, reach its last page, and
 * roll over to the next book in the catalog list via the confirmation dialog.
 */
@RunWith(AndroidJUnit4::class)
class ReaderNextBookTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest) =
                    MockResponse().setResponseCode(200).setBody(PSE_FEED)
            }
            start()
        }
        deleteAllServers()
    }

    @After
    fun tearDown() {
        deleteAllServers()
        server.shutdown()
    }

    @Test
    fun rollsOverToTheNextBookFromTheLastPage() {
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
            composeRule.onAllNodesWithText("Book One").fetchSemanticsNodes().isNotEmpty()
        }

        // Open "Book One" via its detail sheet; it starts on its last page (pse:lastRead).
        composeRule.onNodeWithText("Book One").performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.READ_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.READ_BUTTON).performClick()

        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGER).fetchSemanticsNodes().isNotEmpty()
        }

        // Advancing past the last page offers the next book; confirm it.
        composeRule.onReaderScreen {
            tapLeftZone()
            assertNextBookDialogShown()
            confirmNextBook()
        }

        // The second book's reader is now shown; open the menu to read its title.
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGER).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onReaderScreen { tapCenterZone() }
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText("Book Two").fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun deleteAllServers() {
        composeRule.waitForIdle()
        repeat(MAX_SERVERS) {
            val deletes = composeRule.onAllNodesWithContentDescription("削除").fetchSemanticsNodes()
            if (deletes.isEmpty()) return
            composeRule.onAllNodesWithContentDescription("削除")[0].performClick()
            composeRule.waitForIdle()
        }
    }

    private companion object {
        const val SERVER_NAME = "NextBook E2E"
        const val TIMEOUT = 5_000L
        const val MAX_SERVERS = 20

        // Two image (PSE) books. "Book One" opens on its last page (pse:lastRead == pse:count).
        val PSE_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:dc="http://purl.org/dc/elements/1.1/"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds/recent" type="application/atom+xml"/>
              <entry>
                <title>Book One</title>
                <id>urn:bookwall:book:1</id>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="2" pse:lastRead="2"/>
              </entry>
              <entry>
                <title>Book Two</title>
                <id>urn:bookwall:book:2</id>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/2/pages/{pageNumber}" type="image/jpeg"
                          pse:count="3"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
