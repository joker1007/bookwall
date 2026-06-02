package net.joker1007.bookwall.feature.epubreader

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.net.toUri
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import androidx.fragment.app.commitNow
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.AndroidEntryPoint
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.epub.EpubProgressRepository
import net.joker1007.bookwall.data.epub.EpubReaderHolder
import net.joker1007.bookwall.data.epub.EpubSession
import net.joker1007.bookwall.data.epub.toEpubPreferences
import net.joker1007.bookwall.ui.theme.BookwallTheme
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.input.InputListener
import org.readium.r2.navigator.input.TapEvent
import org.readium.r2.navigator.util.DirectionalNavigationAdapter
import org.readium.r2.shared.ExperimentalReadiumApi
import org.readium.r2.shared.util.AbsoluteUrl
import javax.inject.Inject

/**
 * Hosts Readium's [EpubNavigatorFragment] inside a single Compose tree: the
 * navigator is an [AndroidView] and the chrome (top bar, settings, TOC) draws
 * over it, so Compose owns the layering (a sibling ComposeView over the WebView
 * occluded it). The publication is opened beforehand and stashed in
 * [EpubReaderHolder]; we read it back by session id because the navigator
 * factory must be installed before super.onCreate().
 */
@AndroidEntryPoint
class EpubReaderActivity : FragmentActivity(), EpubNavigatorFragment.Listener {

    @Inject
    lateinit var progressRepository: EpubProgressRepository

    private val viewModel: EpubReaderViewModel by viewModels()

    // Resolved via an entry point because we need it before super.onCreate(),
    // where Hilt field injection has not run yet.
    private lateinit var holder: EpubReaderHolder
    private var navigator: EpubNavigatorFragment? = null
    private var sessionId: Long = -1L
    private var observersStarted = false

    override fun onCreate(savedInstanceState: Bundle?) {
        holder = EntryPointAccessors
            .fromApplication(applicationContext, EpubReaderEntryPoint::class.java)
            .epubReaderHolder()
        sessionId = intent.getLongExtra(EXTRA_SESSION_ID, -1L)
        val session = holder.get(sessionId)
        if (session == null) {
            super.onCreate(savedInstanceState)
            finish()
            return
        }

        supportFragmentManager.fragmentFactory =
            session.navigatorFactory.createFragmentFactory(
                initialLocator = session.initialLocator,
                listener = this,
            )

        super.onCreate(savedInstanceState)

        setContent {
            BookwallTheme {
                Box(modifier = Modifier.fillMaxSize()) {
                    val containerId = remember { View.generateViewId() }
                    AndroidView(
                        modifier = Modifier.fillMaxSize(),
                        factory = { context ->
                            FragmentContainerView(context).apply { id = containerId }
                        },
                        update = {
                            if (navigator == null) {
                                supportFragmentManager.commitNow {
                                    add(containerId, EpubNavigatorFragment::class.java, Bundle(), FRAGMENT_TAG)
                                }
                                onNavigatorReady(session)
                            }
                        },
                    )
                    EpubReaderChrome(
                        title = session.title,
                        toc = session.publication.tableOfContents,
                        viewModel = viewModel,
                        onTocClick = { link ->
                            lifecycleScope.launch { navigator?.go(link) }
                            viewModel.closeToc()
                        },
                        onBack = { finish() },
                    )
                }
            }
        }
    }

    @OptIn(ExperimentalReadiumApi::class)
    private fun onNavigatorReady(session: EpubSession) {
        val nav = supportFragmentManager.findFragmentByTag(FRAGMENT_TAG) as EpubNavigatorFragment
        navigator = nav

        // DirectionalNavigationAdapter turns exactly one page per edge tap and
        // honours the reading progression (RTL / vertical) itself. It consumes
        // edge taps; the second listener then receives only center taps.
        nav.addInputListener(DirectionalNavigationAdapter(nav, handleTapsWhileScrolling = true))
        nav.addInputListener(
            object : InputListener {
                override fun onTap(event: TapEvent): Boolean {
                    viewModel.toggleMenu()
                    return true
                }
            },
        )

        if (!observersStarted) {
            observersStarted = true
            lifecycleScope.launch {
                repeatOnLifecycle(Lifecycle.State.STARTED) {
                    launch {
                        viewModel.settings.collect { nav.submitPreferences(it.toEpubPreferences()) }
                    }
                    launch {
                        nav.currentLocator.collect {
                            progressRepository.save(session.serverId, session.bookId, it)
                        }
                    }
                }
            }
        }
    }

    override fun onExternalLinkActivated(url: AbsoluteUrl) {
        runCatching { startActivity(Intent(Intent.ACTION_VIEW, url.toString().toUri())) }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) holder.remove(sessionId)
    }

    @EntryPoint
    @InstallIn(SingletonComponent::class)
    interface EpubReaderEntryPoint {
        fun epubReaderHolder(): EpubReaderHolder
    }

    companion object {
        private const val EXTRA_SESSION_ID = "session_id"
        private const val FRAGMENT_TAG = "epub_navigator"

        fun intent(context: Context, sessionId: Long): Intent =
            Intent(context, EpubReaderActivity::class.java).putExtra(EXTRA_SESSION_ID, sessionId)
    }
}
