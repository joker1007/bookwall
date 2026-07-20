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
import net.joker1007.bookwall.robot.onCatalogScreen
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
 * End-to-end: from a book's detail sheet, tapping its series name navigates to
 * that series' OPDS sub-catalog (the atom rel="related" link on the entry).
 */
@RunWith(AndroidJUnit4::class)
class CatalogSeriesNavigationTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse {
                    val body = if (request.path.orEmpty().contains("/series/")) SERIES_FEED else CATALOG_FEED
                    return MockResponse().setResponseCode(200).setBody(body)
                }
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
    fun tappingSeriesNameOpensTheSeriesCatalog() {
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

        // Open the detail sheet and tap the series name.
        composeRule.onNodeWithText("Book One").performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.SERIES_LINK).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.SERIES_LINK).performClick()

        // The series sub-catalog opens; its feed title shows in the top bar.
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText("My Series").fetchSemanticsNodes().isNotEmpty()
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
        const val SERVER_NAME = "Series Nav E2E"
        const val TIMEOUT = 5_000L
        const val MAX_SERVERS = 20

        val CATALOG_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds/recent" type="application/atom+xml"/>
              <entry>
                <title>Book One</title>
                <id>urn:bookwall:book:1</id>
                <link rel="related" href="/opds/series/1" title="My Series"
                      type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="2"/>
              </entry>
            </feed>
        """.trimIndent()

        val SERIES_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>My Series</title>
              <id>urn:bookwall:series:1</id>
              <link rel="self" href="/opds/series/1" type="application/atom+xml"/>
              <entry>
                <title>Book One</title>
                <id>urn:bookwall:book:1</id>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="2"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
