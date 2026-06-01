package net.joker1007.bookwall.data.reader

import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.opds.resolveOpdsHref

/**
 * [PageSource] backed by OPDS Page Streaming Extension. Substitutes the page
 * index into the PSE href template and resolves it against the server base.
 */
class OpdsPageSource(
    private val baseUrl: String,
    private val pseTemplate: String,
    override val pageCount: Int,
) : PageSource {
    override fun pageModel(index: Int): Any? {
        if (index !in 0 until pageCount) return null
        val href = pseTemplate.replace(OpdsParser.PSE_PAGE_TOKEN, index.toString())
        return resolveOpdsHref(baseUrl, href)
    }
}
