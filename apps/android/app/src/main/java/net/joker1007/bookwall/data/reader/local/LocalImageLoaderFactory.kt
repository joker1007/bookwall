package net.joker1007.bookwall.data.reader.local

import android.content.Context
import coil3.ImageLoader
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/** Supplies the Coil loader for local book pages; an interface for JVM tests. */
fun interface LocalImageLoaderProvider {
    fun localImageLoader(): ImageLoader
}

/**
 * Coil loader for local book pages (CBZ entries, PDF renders). No disk cache:
 * the source files are already local, so only the memory cache matters.
 */
@Singleton
class LocalImageLoaderFactory @Inject constructor(
    @ApplicationContext private val context: Context,
) : LocalImageLoaderProvider {

    private val imageLoader: ImageLoader by lazy {
        ImageLoader.Builder(context)
            .components {
                add(CbzPageFetcher.Factory())
                add(PdfPageFetcher.Factory())
                add(CbzPageKeyer())
                add(PdfPageKeyer())
            }
            .build()
    }

    override fun localImageLoader(): ImageLoader = imageLoader
}
