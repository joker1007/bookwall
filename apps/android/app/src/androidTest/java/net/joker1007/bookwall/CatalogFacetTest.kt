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

/** End-to-end: open the facet sheet and narrow the catalog by a tag facet (server-side). */
@RunWith(AndroidJUnit4::class)
class CatalogFacetTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse {
                    val body = if (request.requestUrl?.queryParameter("tag_id") == "5") FILTERED_FEED else FACET_FEED
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
    fun narrowsCatalogByTagFacet() {
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
            composeRule.onAllNodesWithText("Other Book").fetchSemanticsNodes().isNotEmpty()
        }

        composeRule.onCatalogScreen {
            openFacetSheet()
            selectFacet("manga")
        }

        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText("Other Book").fetchSemanticsNodes().isEmpty()
        }
        composeRule.onCatalogScreen {
            assertEntryShown("Manga Book")
            assertEntryAbsent("Other Book")
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
        const val SERVER_NAME = "Facet E2E"
        const val TIMEOUT = 5_000L
        const val MAX_SERVERS = 20

        val FACET_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog" xmlns:thr="http://purl.org/syndication/thread/1.0">
              <title>Library</title>
              <id>urn:bookwall:library:1</id>
              <link rel="self" href="/opds/libraries/1" type="application/atom+xml"/>
              <link rel="http://opds-spec.org/facet" href="/opds?tag_id=5" title="manga" opds:facetGroup="Tags" thr:count="1"/>
              <entry>
                <title>Manga Book</title>
                <id>urn:bookwall:book:1</id>
                <category term="manga"/>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/1/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
              <entry>
                <title>Other Book</title>
                <id>urn:bookwall:book:2</id>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/2/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
            </feed>
        """.trimIndent()

        val FILTERED_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog" xmlns:thr="http://purl.org/syndication/thread/1.0">
              <title>Library</title>
              <id>urn:bookwall:library:1</id>
              <link rel="self" href="/opds/libraries/1?tag_id=5" type="application/atom+xml"/>
              <link rel="http://opds-spec.org/facet" href="/opds?tag_id=5" title="manga" opds:facetGroup="Tags" thr:count="1" opds:activeFacet="true"/>
              <entry>
                <title>Manga Book</title>
                <id>urn:bookwall:book:1</id>
                <category term="manga"/>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/1/file.cbz" type="application/vnd.comicbook+zip"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
