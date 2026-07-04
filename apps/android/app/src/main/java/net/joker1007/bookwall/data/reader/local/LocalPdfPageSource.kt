package net.joker1007.bookwall.data.reader.local

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

/** A page of an open PDF; rendered to a bitmap by [PdfPageFetcher]. */
data class PdfPage(val source: LocalPdfPageSource, val index: Int)

/**
 * Renders PDF pages with the platform [PdfRenderer]. The renderer is not
 * thread-safe and allows only one open page at a time, so all rendering is
 * serialized through a [Mutex] (Coil prefetches pages concurrently).
 */
class LocalPdfPageSource private constructor(
    private val fd: ParcelFileDescriptor,
    private val renderer: PdfRenderer,
    val filePath: String,
) : ClosablePageSource {

    private val mutex = Mutex()

    override val pageCount: Int = renderer.pageCount

    override fun pageModel(index: Int): Any? =
        if (index in 0 until pageCount) PdfPage(this, index) else null

    fun cacheKey(index: Int): String = "pdf:$filePath:$index"

    /** Renders page [index] scaled to [targetWidth] px (0 = default 2x page size). */
    suspend fun render(index: Int, targetWidth: Int): Bitmap = mutex.withLock {
        val page = renderer.openPage(index)
        try {
            val scale = if (targetWidth > 0) targetWidth.toFloat() / page.width else DEFAULT_SCALE
            val width = (page.width * scale).toInt().coerceAtLeast(1)
            val height = (page.height * scale).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            // PDF pages composite onto transparent by default; white matches paper.
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            bitmap
        } finally {
            page.close()
        }
    }

    override fun close() {
        renderer.close()
        fd.close()
    }

    companion object {
        private const val DEFAULT_SCALE = 2f

        fun open(file: File): LocalPdfPageSource {
            val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            return LocalPdfPageSource(fd, PdfRenderer(fd), file.absolutePath)
        }
    }
}
