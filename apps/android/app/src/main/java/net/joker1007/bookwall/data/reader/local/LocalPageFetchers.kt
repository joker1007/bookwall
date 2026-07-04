package net.joker1007.bookwall.data.reader.local

import coil3.ImageLoader
import coil3.asImage
import coil3.decode.DataSource
import coil3.decode.ImageSource
import coil3.fetch.FetchResult
import coil3.fetch.Fetcher
import coil3.fetch.ImageFetchResult
import coil3.fetch.SourceFetchResult
import coil3.key.Keyer
import coil3.request.Options
import coil3.size.pxOrElse
import okio.buffer
import okio.source

/** Streams a CBZ page image out of the archive for Coil to decode. */
class CbzPageFetcher(
    private val page: CbzPage,
    private val options: Options,
) : Fetcher {

    override suspend fun fetch(): FetchResult = SourceFetchResult(
        source = ImageSource(page.source.openPage(page.index).source().buffer(), options.fileSystem),
        mimeType = null,
        dataSource = DataSource.DISK,
    )

    class Factory : Fetcher.Factory<CbzPage> {
        override fun create(data: CbzPage, options: Options, imageLoader: ImageLoader): Fetcher =
            CbzPageFetcher(data, options)
    }
}

/** Renders a PDF page to a bitmap sized to the request target. */
class PdfPageFetcher(
    private val page: PdfPage,
    private val options: Options,
) : Fetcher {

    override suspend fun fetch(): FetchResult {
        val targetWidth = options.size.width.pxOrElse { 0 }
        val bitmap = page.source.render(page.index, targetWidth)
        return ImageFetchResult(bitmap.asImage(), isSampled = true, dataSource = DataSource.DISK)
    }

    class Factory : Fetcher.Factory<PdfPage> {
        override fun create(data: PdfPage, options: Options, imageLoader: ImageLoader): Fetcher =
            PdfPageFetcher(data, options)
    }
}

class CbzPageKeyer : Keyer<CbzPage> {
    override fun key(data: CbzPage, options: Options): String = data.source.cacheKey(data.index)
}

class PdfPageKeyer : Keyer<PdfPage> {
    override fun key(data: PdfPage, options: Options): String = data.source.cacheKey(data.index)
}
