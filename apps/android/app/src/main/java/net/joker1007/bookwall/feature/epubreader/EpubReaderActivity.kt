package net.joker1007.bookwall.feature.epubreader

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.core.net.toUri
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import androidx.fragment.app.commitNow
import dagger.hilt.android.AndroidEntryPoint
import net.joker1007.bookwall.data.epub.EpubReaderHolder
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.shared.util.AbsoluteUrl
import javax.inject.Inject

/**
 * Hosts Readium's [EpubNavigatorFragment]. The publication is opened beforehand
 * and stashed in [EpubReaderHolder]; we read it back here by session id because
 * the navigator factory must be installed before super.onCreate().
 */
@AndroidEntryPoint
class EpubReaderActivity : FragmentActivity(), EpubNavigatorFragment.Listener {

    @Inject
    lateinit var holder: EpubReaderHolder

    private var sessionId: Long = -1L

    override fun onCreate(savedInstanceState: Bundle?) {
        sessionId = intent.getLongExtra(EXTRA_SESSION_ID, -1L)
        val session = holder.get(sessionId)
        if (session == null) {
            super.onCreate(savedInstanceState)
            finish()
            return
        }

        supportFragmentManager.fragmentFactory =
            session.navigatorFactory.createFragmentFactory(initialLocator = null, listener = this)

        super.onCreate(savedInstanceState)

        val containerId = View.generateViewId()
        val container = FragmentContainerView(this).apply {
            id = containerId
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        setContentView(container)

        if (savedInstanceState == null) {
            supportFragmentManager.commitNow {
                add(containerId, EpubNavigatorFragment::class.java, Bundle(), FRAGMENT_TAG)
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

    companion object {
        private const val EXTRA_SESSION_ID = "session_id"
        private const val FRAGMENT_TAG = "epub_navigator"

        fun intent(context: Context, sessionId: Long): Intent =
            Intent(context, EpubReaderActivity::class.java).putExtra(EXTRA_SESSION_ID, sessionId)
    }
}
