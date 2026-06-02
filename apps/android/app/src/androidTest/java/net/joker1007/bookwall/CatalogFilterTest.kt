package net.joker1007.bookwall

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
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

/** End-to-end: add a server, open its catalog, and filter the loaded entries client-side. */
@RunWith(AndroidJUnit4::class)
class CatalogFilterTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest) =
                    MockResponse().setResponseCode(200).setBody(ACQUISITION_FEED)
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
    fun filtersCatalogEntriesByQuery() {
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
            composeRule.onAllNodesWithText("Zzz Book").fetchSemanticsNodes().isNotEmpty()
        }

        composeRule.onCatalogScreen {
            openFilter()
            typeFilter("Zzz Book")
            assertEntryShown("Zzz Book")
            assertEntryAbsent("Aaa Book")
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
        const val SERVER_NAME = "Filter E2E"
        const val TIMEOUT = 5_000L
        const val MAX_SERVERS = 20

        val ACQUISITION_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds/recent" type="application/atom+xml"/>
              <entry>
                <title>Zzz Book</title>
                <id>urn:bookwall:book:1</id>
                <author><name>Aaa Author</name></author>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/1/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
              <entry>
                <title>Aaa Book</title>
                <id>urn:bookwall:book:2</id>
                <author><name>Zzz Author</name></author>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/2/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
