package net.joker1007.bookwall.feature.epubreader

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.activity.viewModels
import androidx.compose.ui.platform.ComposeView
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
import org.readium.r2.shared.util.AbsoluteUrl
import javax.inject.Inject

/**
 * Hosts Readium's [EpubNavigatorFragment] with a Compose chrome (top bar,
 * settings, TOC) overlaid. The publication is opened beforehand and stashed in
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
    private lateinit var navigator: EpubNavigatorFragment
    private var sessionId: Long = -1L

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

        val containerId = View.generateViewId()
        val root = FrameLayout(this).apply {
            addView(
                FragmentContainerView(this@EpubReaderActivity).apply {
                    id = containerId
                    layoutParams = FrameLayout.LayoutParams(MATCH, MATCH)
                },
            )
            addView(
                ComposeView(this@EpubReaderActivity).apply {
                    layoutParams = FrameLayout.LayoutParams(MATCH, MATCH)
                    setContent {
                        BookwallTheme {
                            EpubReaderChrome(
                                title = session.title,
                                toc = session.publication.tableOfContents,
                                viewModel = viewModel,
                                onTocClick = { link ->
                                    lifecycleScope.launch { navigator.go(link) }
                                    viewModel.closeToc()
                                },
                                onBack = { finish() },
                            )
                        }
                    }
                },
            )
        }
        setContentView(root)

        if (savedInstanceState == null) {
            supportFragmentManager.commitNow {
                add(containerId, EpubNavigatorFragment::class.java, Bundle(), FRAGMENT_TAG)
            }
        }
        navigator = supportFragmentManager.findFragmentByTag(FRAGMENT_TAG) as EpubNavigatorFragment

        navigator.addInputListener(
            object : InputListener {
                override fun onTap(event: TapEvent): Boolean {
                    val width = resources.displayMetrics.widthPixels
                    val third = width / 3f
                    return if (event.point.x > third && event.point.x < width - third) {
                        viewModel.toggleMenu()
                        true
                    } else {
                        false
                    }
                }
            },
        )

        observeSession(session)
    }

    private fun observeSession(session: EpubSession) {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    viewModel.settings.collect { navigator.submitPreferences(it.toEpubPreferences()) }
                }
                launch {
                    navigator.currentLocator.collect {
                        progressRepository.save(session.serverId, session.bookId, it)
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
        private const val MATCH = FrameLayout.LayoutParams.MATCH_PARENT

        fun intent(context: Context, sessionId: Long): Intent =
            Intent(context, EpubReaderActivity::class.java).putExtra(EXTRA_SESSION_ID, sessionId)
    }
}
