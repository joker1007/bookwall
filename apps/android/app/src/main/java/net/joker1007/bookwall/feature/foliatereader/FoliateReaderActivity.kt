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
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.lifecycleScope
import androidx.webkit.WebViewAssetLoader
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.epub.EpubProgressRepository
import net.joker1007.bookwall.data.opds.OpdsEntry
import net.joker1007.bookwall.data.reader.BookOpenCoordinator
import net.joker1007.bookwall.data.reader.ProgressSyncRepository
import net.joker1007.bookwall.data.reader.ProgressSyncScheduler
import net.joker1007.bookwall.data.reader.ReadingQueueHolder
import net.joker1007.bookwall.data.reader.reconcileEpubCfi
import net.joker1007.bookwall.data.server.OpdsServer
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.feature.epubreader.EpubReaderViewModel
import net.joker1007.bookwall.ui.NextBookDialog
import net.joker1007.bookwall.ui.theme.BookwallTheme
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import javax.inject.Inject

/**
 * Hosts foliate-js in a WebView to render EPUBs (the same engine the web reader
 * uses, so CFIs are interoperable). The reader HTML/JS is served from assets via
 * [WebViewAssetLoader] on a single origin so foliate's ES module imports resolve;
 * the downloaded EPUB file is served under /epub/ by a custom path handler.
 *
 * Native chrome (top bar, settings, TOC, scrubber, immersive) is layered in P2.
 */
/** Escapes a string for embedding inside a single-quoted JS string literal. */
private fun String.jsEscape(): String = replace("\\", "\\\\").replace("'", "\\'")

@AndroidEntryPoint
class FoliateReaderActivity : ComponentActivity() {

    private val viewModel: EpubReaderViewModel by viewModels()

    @Inject lateinit var epubProgressRepository: EpubProgressRepository

    @Inject lateinit var progressSyncRepository: ProgressSyncRepository

    @Inject lateinit var progressSyncScheduler: ProgressSyncScheduler

    @Inject lateinit var serverRepository: ServerRepository

    @Inject lateinit var readingQueueHolder: ReadingQueueHolder

    @Inject lateinit var bookOpenCoordinator: BookOpenCoordinator

    private lateinit var epubFile: File
    private lateinit var title: String
    private var serverId: Long = 0L
    private var bookId: Long = 0L
    private var server: OpdsServer? = null
    private var nextBook: OpdsEntry.Book? = null
    private var confirmNextBook by mutableStateOf<OpdsEntry.Book?>(null)
    /** Completes with the CFI to restore on open (local vs server reconciled). */
    private val initialCfi = CompletableDeferred<String?>()
    private var saveJob: Job? = null

    private var loadState by mutableStateOf<LoadState>(LoadState.Loading)
    private var toc by mutableStateOf<List<TocEntry>>(emptyList())
    private var fraction by mutableStateOf(0f)
    /** True for right-to-left / vertical books, used to flip tap-zone paging. */
    private var rtl by mutableStateOf(false)

    private var webView: WebView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val path = intent.getStringExtra(EXTRA_FILE_PATH)
        if (path == null) {
            finish()
            return
        }
        epubFile = File(path)
        title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        serverId = intent.getLongExtra(EXTRA_SERVER_ID, 0L)
        bookId = intent.getLongExtra(EXTRA_BOOK_ID, 0L)
        nextBook = readingQueueHolder.nextAfter(serverId, bookId)

        // Resolve the restore position in parallel with the WebView loading: the
        // furthest of the local save and the server's progress (pulled if the
        // server supports sync). onReady() awaits this before opening.
        lifecycleScope.launch {
            val srv = serverRepository.getServer(serverId)
            server = srv
            val local = epubProgressRepository.load(serverId, bookId)
            val remote = srv?.let { progressSyncRepository.pullEpubProgress(it, bookId) }
            initialCfi.complete(
                reconcileEpubCfi(local?.cfi, local?.fraction, remote?.cfi, remote?.fraction),
            )
        }

        enableEdgeToEdge()
        setContent {
            BookwallTheme {
                val settings by viewModel.settings.collectAsState()
                val chrome by viewModel.chrome.collectAsState()

                LaunchedEffect(settings) {
                    runJs("window.foliateGlue.setStyles('${foliateStylesJson(settings)}')")
                }

                Box(modifier = Modifier.fillMaxSize()) {
                    AndroidView(
                        modifier = Modifier.fillMaxSize(),
                        factory = { context -> createWebView(context) },
                    )
                    FoliateReaderChrome(
                        title = title,
                        toc = toc,
                        fraction = fraction,
                        viewModel = viewModel,
                        onTocClick = { entry ->
                            entry.href?.let { runJs("window.foliateGlue.goTo('${it.jsEscape()}')") }
                            viewModel.closeToc()
                        },
                        onSeek = { f -> runJs("window.foliateGlue.goToFraction($f)") },
                        onBack = { finish() },
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
                confirmNextBook?.let { next ->
                    NextBookDialog(
                        title = next.title,
                        onConfirm = {
                            confirmNextBook = null
                            bookOpenCoordinator.request(serverId, next)
                            finish()
                        },
                        onDismiss = { confirmNextBook = null },
                    )
                }
                FoliateImmersiveEffect(chrome.menuVisible)
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createWebView(context: Context): WebView {
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
            addJavascriptInterface(Bridge(), "AndroidBridge")
            loadUrl("https://appassets.androidplatform.net/foliate/reader.html")
        }
    }

    private fun runJs(script: String) {
        webView?.post { webView?.evaluateJavascript(script, null) }
    }

    private fun goForward(forward: Boolean) =
        runJs(if (forward) "window.foliateGlue.next()" else "window.foliateGlue.prev()")

    /** Debounced: persist locally, push to the server, defer to the worker offline. */
    private fun persistProgress(cfi: String, fraction: Float) {
        saveJob?.cancel()
        saveJob = lifecycleScope.launch {
            delay(SAVE_DEBOUNCE_MS)
            epubProgressRepository.save(serverId, bookId, cfi, fraction)
            server?.let { srv ->
                if (!srv.supportsProgressSync) return@let
                if (progressSyncRepository.pushEpubProgress(srv, bookId, cfi, fraction)) {
                    epubProgressRepository.markSynced(serverId, bookId)
                } else {
                    progressSyncScheduler.schedule()
                }
            }
        }
    }

    /** JS -> Kotlin callbacks. Invoked on a binder thread; hop to the WebView thread for JS calls. */
    private inner class Bridge {
        @JavascriptInterface
        fun onReady() {
            lifecycleScope.launch {
                val cfi = initialCfi.await()
                val cfiArg = cfi?.let { "'${it.jsEscape()}'" } ?: "null"
                // Seed styles before open so the first section renders with them.
                runJs("window.foliateGlue.setStyles('${foliateStylesJson(viewModel.settings.value)}')")
                runJs("window.foliateGlue.open('https://appassets.androidplatform.net/epub/book.epub', $cfiArg)")
            }
        }

        @JavascriptInterface
        fun onBookOpened(tocJson: String, dir: String, sectionTotal: Int) {
            runOnUiThread {
                toc = parseToc(tocJson)
                rtl = dir == "rtl"
                loadState = LoadState.Ready
            }
        }

        @JavascriptInterface
        fun onRelocate(cfi: String, fraction: Double) {
            val f = fraction.toFloat()
            runOnUiThread { this@FoliateReaderActivity.fraction = f }
            persistProgress(cfi, f)
        }

        @JavascriptInterface
        fun onWritingModeDetected(mode: String) {
            if (mode == "vertical") runOnUiThread { rtl = true }
        }

        @JavascriptInterface
        fun onTap(zone: String) {
            when (zone) {
                "center" -> runOnUiThread { viewModel.toggleMenu() }
                // In LTR a right tap advances; RTL/vertical flips it.
                "right" -> goForward(forward = !rtl)
                "left" -> goForward(forward = rtl)
            }
        }

        @JavascriptInterface
        fun onSwipe(direction: String) {
            // Swiping content left advances in LTR; RTL flips it.
            when (direction) {
                "left" -> goForward(forward = !rtl)
                "right" -> goForward(forward = rtl)
            }
        }

        @JavascriptInterface
        fun onReachedEnd() {
            val next = nextBook ?: return
            runOnUiThread { confirmNextBook = next }
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
        private const val SAVE_DEBOUNCE_MS = 1_000L
        private const val EXTRA_SERVER_ID = "server_id"
        private const val EXTRA_BOOK_ID = "book_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_FILE_PATH = "file_path"

        fun intent(
            context: Context,
            serverId: Long,
            bookId: Long,
            title: String,
            filePath: String,
        ): Intent = Intent(context, FoliateReaderActivity::class.java).apply {
            putExtra(EXTRA_SERVER_ID, serverId)
            putExtra(EXTRA_BOOK_ID, bookId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_FILE_PATH, filePath)
        }
    }
}
