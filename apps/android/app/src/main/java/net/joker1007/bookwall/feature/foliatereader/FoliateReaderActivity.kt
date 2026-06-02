package net.joker1007.bookwall.feature.foliatereader

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.WebViewAssetLoader
import dagger.hilt.android.AndroidEntryPoint
import net.joker1007.bookwall.ui.theme.BookwallTheme
import java.io.File
import java.io.FileInputStream
import java.io.IOException

/**
 * Hosts foliate-js in a WebView to render EPUBs (the same engine the web reader
 * uses, so CFIs are interoperable). The reader HTML/JS is served from assets via
 * [WebViewAssetLoader] on a single origin so foliate's ES module imports resolve;
 * the downloaded EPUB file is served under /epub/ by a custom path handler.
 *
 * Native chrome (top bar, settings, TOC, scrubber, immersive) is layered in P2.
 */
@AndroidEntryPoint
class FoliateReaderActivity : ComponentActivity() {

    private lateinit var epubFile: File
    private var loadState by mutableStateOf<LoadState>(LoadState.Loading)

    private var webView: WebView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val path = intent.getStringExtra(EXTRA_FILE_PATH)
        if (path == null) {
            finish()
            return
        }
        epubFile = File(path)
        val initialCfi = intent.getStringExtra(EXTRA_INITIAL_CFI)

        enableEdgeToEdge()
        setContent {
            BookwallTheme {
                Box(modifier = Modifier.fillMaxSize()) {
                    AndroidView(
                        modifier = Modifier.fillMaxSize(),
                        factory = { context -> createWebView(context, initialCfi) },
                    )
                    when (val s = loadState) {
                        LoadState.Loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                        is LoadState.Error -> Text(
                            text = "読み込みに失敗しました: ${s.message}",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.align(Alignment.Center),
                        )
                        LoadState.Ready -> Unit
                    }
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createWebView(context: Context, initialCfi: String?): WebView {
        val assetLoader = WebViewAssetLoader.Builder()
            // Serve assets/foliate/<path> at /foliate/<path> (the default
            // AssetsPathHandler maps the suffix to the assets *root*, so it would
            // look for assets/<path> and miss our foliate/ subdirectory).
            .addPathHandler("/foliate/", FoliateAssetPathHandler(context))
            .addPathHandler("/epub/", EpubPathHandler(epubFile))
            .build()

        WebView.setWebContentsDebuggingEnabled(true)
        return WebView(context).apply {
            webView = this
            // A freshly-created WebView defaults to WRAP_CONTENT, which makes
            // Compose's AndroidView measure it with an UNSPECIFIED height; the
            // page's layout viewport then collapses to 0 and CSS %/vh heights
            // resolve to 0 (blank). MATCH_PARENT gives it a definite height.
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            settings.javaScriptEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            // Always read fresh assets so reader.html/js/css edits take effect
            // without a full reinstall and aren't served from a stale cache.
            settings.cacheMode = WebSettings.LOAD_NO_CACHE
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest,
                ): WebResourceResponse? = assetLoader.shouldInterceptRequest(request.url)

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    Log.e(TAG, "load error ${error.errorCode} ${error.description} @ ${request.url}")
                }
            }
            webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(msg: ConsoleMessage): Boolean {
                    Log.d(TAG, "console ${msg.messageLevel()} ${msg.message()} @${msg.sourceId()}:${msg.lineNumber()}")
                    return true
                }
            }
            addJavascriptInterface(Bridge(initialCfi), "AndroidBridge")
            loadUrl("https://appassets.androidplatform.net/foliate/reader.html")
        }
    }

    private fun runJs(script: String) {
        webView?.post { webView?.evaluateJavascript(script, null) }
    }

    /** JS -> Kotlin callbacks. Invoked on a binder thread; hop to the WebView thread for JS calls. */
    private inner class Bridge(private val initialCfi: String?) {
        @JavascriptInterface
        fun onReady() {
            val cfiArg = initialCfi?.let { "'${it.replace("'", "\\'")}'" } ?: "null"
            runJs("window.foliateGlue.open('https://appassets.androidplatform.net/epub/book.epub', $cfiArg)")
        }

        @JavascriptInterface
        fun onBookOpened(tocJson: String, dir: String, sectionTotal: Int) {
            runOnUiThread { loadState = LoadState.Ready }
        }

        @JavascriptInterface
        fun onRelocate(cfi: String, fraction: Double) {
            // Persistence + sync wired in P4.
        }

        @JavascriptInterface
        fun onWritingModeDetected(mode: String) {
            // Used by chrome (tap-zone flip) in P2.
        }

        @JavascriptInterface
        fun onTap(zone: String) {
            // P1: basic LTR navigation so the book is readable; direction flip
            // and center-tap menu come in P2.
            when (zone) {
                "left" -> runJs("window.foliateGlue.prev()")
                "right" -> runJs("window.foliateGlue.next()")
            }
        }

        @JavascriptInterface
        fun onSwipe(direction: String) {
            when (direction) {
                "left" -> runJs("window.foliateGlue.next()")
                "right" -> runJs("window.foliateGlue.prev()")
            }
        }

        @JavascriptInterface
        fun onError(message: String) {
            runOnUiThread { loadState = LoadState.Error(message) }
        }
    }

    override fun onDestroy() {
        webView?.destroy()
        webView = null
        super.onDestroy()
    }

    private sealed interface LoadState {
        data object Loading : LoadState
        data object Ready : LoadState
        data class Error(val message: String) : LoadState
    }

    /**
     * Serves assets/foliate/<path>. [path] is the URL suffix after the registered
     * "/foliate/" prefix. Sets explicit MIME types: ES module scripts are rejected
     * by the WebView unless served with a JavaScript MIME type.
     */
    private class FoliateAssetPathHandler(private val context: Context) : WebViewAssetLoader.PathHandler {
        override fun handle(path: String): WebResourceResponse? {
            val assetPath = "foliate/" + path.trimStart('/')
            return try {
                val (mime, encoding) = mimeOf(assetPath)
                WebResourceResponse(
                    mime, encoding, 200, "OK",
                    mapOf("Cache-Control" to "no-store"),
                    context.assets.open(assetPath),
                )
            } catch (e: IOException) {
                Log.e(TAG, "asset not found: $assetPath")
                WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), null)
            }
        }

        private fun mimeOf(path: String): Pair<String, String?> = when {
            path.endsWith(".html") -> "text/html" to "utf-8"
            path.endsWith(".js") -> "text/javascript" to "utf-8"
            path.endsWith(".css") -> "text/css" to "utf-8"
            path.endsWith(".json") -> "application/json" to "utf-8"
            path.endsWith(".svg") -> "image/svg+xml" to "utf-8"
            else -> "application/octet-stream" to null
        }
    }

    /** Serves the single downloaded EPUB file under /epub/ regardless of the leaf name. */
    private class EpubPathHandler(private val file: File) : WebViewAssetLoader.PathHandler {
        override fun handle(path: String): WebResourceResponse? = try {
            WebResourceResponse(
                "application/epub+zip",
                null,
                200,
                "OK",
                mapOf("Access-Control-Allow-Origin" to "*"),
                FileInputStream(file),
            )
        } catch (e: Exception) {
            Log.e(TAG, "epub read failed: ${e.message}")
            null
        }
    }

    companion object {
        private const val TAG = "FoliateReader"
        private const val EXTRA_SERVER_ID = "server_id"
        private const val EXTRA_BOOK_ID = "book_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_FILE_PATH = "file_path"
        private const val EXTRA_INITIAL_CFI = "initial_cfi"

        fun intent(
            context: Context,
            serverId: Long,
            bookId: Long,
            title: String,
            filePath: String,
            initialCfi: String?,
        ): Intent = Intent(context, FoliateReaderActivity::class.java).apply {
            putExtra(EXTRA_SERVER_ID, serverId)
            putExtra(EXTRA_BOOK_ID, bookId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_FILE_PATH, filePath)
            putExtra(EXTRA_INITIAL_CFI, initialCfi)
        }
    }
}
