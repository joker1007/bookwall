package net.joker1007.bookwall.data.reader

/**
 * Groups page indices into reader slots. Single mode yields one page per slot;
 * spread mode pairs two pages per slot. [offset] == 1 makes the first page a
 * lone slot, shifting pairing by one to realign mismatched spreads.
 */
fun buildSpreads(pageCount: Int, spreadEnabled: Boolean, offset: Int): List<List<Int>> {
    if (pageCount <= 0) return emptyList()
    if (!spreadEnabled) return (0 until pageCount).map { listOf(it) }

    val slots = mutableListOf<List<Int>>()
    var i = 0
    if (offset % 2 == 1) {
        slots += listOf(0)
        i = 1
    }
    while (i < pageCount) {
        if (i + 1 < pageCount) {
            slots += listOf(i, i + 1)
            i += 2
        } else {
            slots += listOf(i)
            i += 1
        }
    }
    return slots
}

/** Index of the slot that contains [page], or 0 if not found. */
fun slotIndexForPage(slots: List<List<Int>>, page: Int): Int =
    slots.indexOfFirst { page in it }.coerceAtLeast(0)
