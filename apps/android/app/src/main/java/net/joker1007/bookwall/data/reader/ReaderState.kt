package net.joker1007.bookwall.data.reader

enum class ReadingDirection { LTR, RTL }

/** Per-book reader state: reading position and book-scoped settings. */
data class ReaderState(
    val currentPage: Int = 0,
    val direction: ReadingDirection = ReadingDirection.RTL,
    val spreadMode: SpreadMode = SpreadMode.OFF,
)
