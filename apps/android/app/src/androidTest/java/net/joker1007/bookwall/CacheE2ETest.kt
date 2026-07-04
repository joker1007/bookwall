package net.joker1007.bookwall

import android.graphics.Bitmap
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso
import androidx.test.ext.junit.runners.AndroidJUnit4
import net.joker1007.bookwall.feature.catalog.BookDetailTags
import net.joker1007.bookwall.feature.catalog.CatalogTags
import net.joker1007.bookwall.feature.downloads.DownloadsTags
import net.joker1007.bookwall.feature.reader.ReaderTags
import net.joker1007.bookwall.feature.servers.ServersScreenTags
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
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * End-to-end offline cache flows: manual download with badge + delete, offline
 * open of the cached CBZ (server down), and the downloads screen.
 */
@RunWith(AndroidJUnit4::class)
class CacheE2ETest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer().apply {
            dispatcher = object : Dispatcher() {
                override fun dispatch(request: RecordedRequest): MockResponse = when {
                    request.path == "/opds" -> MockResponse().setResponseCode(200).setBody(FEED)
                    request.path == "/opds/books/1/file.cbz" ->
                        MockResponse().setResponseCode(200).setBody(Buffer().write(cbzBytes()))
                    request.path!!.startsWith("/opds/books/1/pages/") ->
                        MockResponse().setResponseCode(200).setBody(Buffer().write(pngBytes()))
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
    fun downloadsFromDetailShowsBadgeAndDeletesCache() {
        openCatalog()

        composeRule.onNodeWithText(BOOK_TITLE).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.DOWNLOAD_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.DOWNLOAD_BUTTON).performClick()

        // The background worker completes the download; the badge turns into a check.
        composeRule.waitUntil(DOWNLOAD_TIMEOUT) {
            composeRule.onAllNodesWithContentDescription("ダウンロード済み").fetchSemanticsNodes().isNotEmpty()
        }

        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.DELETE_CACHE_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.DELETE_CACHE_BUTTON).performClick()
        composeRule.onNodeWithTag(BookDetailTags.DELETE_CACHE_CONFIRM).performClick()

        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(CatalogTags.CACHE_BADGE).fetchSemanticsNodes().isEmpty()
        }
    }

    @Test
    fun opensCachedBookOfflineFromDownloadsScreen() {
        openCatalog()

        composeRule.onNodeWithText(BOOK_TITLE).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.DOWNLOAD_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.DOWNLOAD_BUTTON).performClick()
        composeRule.waitUntil(DOWNLOAD_TIMEOUT) {
            composeRule.onAllNodesWithContentDescription("ダウンロード済み").fetchSemanticsNodes().isNotEmpty()
        }

        // Everything from here on must work without the server.
        server.shutdown()

        Espresso.pressBack() // close the detail sheet
        composeRule.waitForIdle()
        Espresso.pressBack() // catalog -> servers
        composeRule.onServersScreen { assertScreenDisplayed() }
        composeRule.onNodeWithTag(ServersScreenTags.DOWNLOADS_BUTTON).performClick()

        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithText(BOOK_TITLE).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText(BOOK_TITLE).performClick()

        // The cached CBZ opens in the image reader fully offline.
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGER).fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun autoCachesTheBookOpenedInTheReader() {
        openCatalog()

        // Default settings: auto-cache on read is ON. Just read the book.
        composeRule.onNodeWithText(BOOK_TITLE).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(BookDetailTags.READ_BUTTON).fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithTag(BookDetailTags.READ_BUTTON).performClick()
        composeRule.waitUntil(TIMEOUT) {
            composeRule.onAllNodesWithTag(ReaderTags.PAGER).fetchSemanticsNodes().isNotEmpty()
        }

        Espresso.pressBack() // reader -> catalog
        composeRule.waitUntil(DOWNLOAD_TIMEOUT) {
            composeRule.onAllNodesWithTag(CatalogTags.CACHE_BADGE).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun openCatalog() {
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
    }

    /** Removes servers (which cascades cached books) so runs stay independent. */
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
        const val SERVER_NAME = "Cache E2E"
        const val BOOK_TITLE = "Cache Book"
        const val TIMEOUT = 5_000L
        const val DOWNLOAD_TIMEOUT = 30_000L
        const val MAX_SERVERS = 20

        fun pngBytes(): ByteArray {
            val bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            return out.toByteArray()
        }

        fun cbzBytes(): ByteArray {
            val out = ByteArrayOutputStream()
            ZipOutputStream(out).use { zip ->
                listOf("001.png", "002.png").forEach { name ->
                    zip.putNextEntry(ZipEntry(name))
                    zip.write(pngBytes())
                    zip.closeEntry()
                }
            }
            return out.toByteArray()
        }

        val FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:dc="http://purl.org/dc/elements/1.1/"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <link rel="self" href="/opds" type="application/atom+xml"/>
              <entry>
                <title>Cache Book</title>
                <id>urn:bookwall:book:1</id>
                <author><name>Author A</name></author>
                <link rel="http://opds-spec.org/acquisition"
                      href="/opds/books/1/file.cbz" type="application/x-cbz" length="1024"/>
                <pse:link rel="http://vaemendis.net/opds-pse/stream"
                          href="/opds/books/1/pages/{pageNumber}" type="image/jpeg"
                          pse:count="2"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
