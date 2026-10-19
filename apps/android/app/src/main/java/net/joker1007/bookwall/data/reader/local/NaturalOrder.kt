package net.joker1007.bookwall.data.reader.local

/**
 * Case-insensitive natural order where digit runs compare numerically, so
 * "2.jpg" precedes "10.jpg". Ties fall back to the raw name. Mirrors the
 * server's `Parsers.natural_sort` so page indices stay PSE-compatible.
 */
object NaturalOrder : Comparator<String> {
    private val CHUNK = Regex("""\d+|\D+""")
    private val COVER_NAME = Regex("""(?<![a-z])cover(?![a-z])|表紙""")
    private val BACK_COVER_NAME = Regex("""(?<![a-z])(?:back|ura)(?![a-z])|裏""")

    /**
     * Natural order, with the first file explicitly named as a front cover
     * moved to the front. Mirrors the server's `Parsers.order_pages`.
     */
    fun orderPages(names: List<String>): List<String> {
        val sorted = names.sortedWith(this)
        val cover = sorted.firstOrNull(::isCoverName) ?: return sorted
        return listOf(cover) + (sorted - cover)
    }

    private fun isCoverName(name: String): Boolean {
        val base = name.substringAfterLast('/').substringBeforeLast('.').lowercase()
        return COVER_NAME.containsMatchIn(base) && !BACK_COVER_NAME.containsMatchIn(base)
    }

    override fun compare(a: String, b: String): Int {
        val ca = chunks(a)
        val cb = chunks(b)
        for (i in 0 until minOf(ca.size, cb.size)) {
            val c = compareChunk(ca[i], cb[i])
            if (c != 0) return c
        }
        if (ca.size != cb.size) return ca.size.compareTo(cb.size)
        return a.compareTo(b)
    }

    private fun chunks(s: String): List<String> = CHUNK.findAll(s.lowercase()).map { it.value }.toList()

    private fun compareChunk(a: String, b: String): Int {
        val aDigit = a[0].isAsciiDigit()
        val bDigit = b[0].isAsciiDigit()
        if (aDigit != bDigit) return if (aDigit) -1 else 1
        if (!aDigit) return a.compareTo(b)
        val na = a.trimStart('0')
        val nb = b.trimStart('0')
        if (na.length != nb.length) return na.length.compareTo(nb.length)
        return na.compareTo(nb)
    }

    private fun Char.isAsciiDigit() = this in '0'..'9'
}
