package net.joker1007.bookwall.data.reader

/** Two-page spread setting. AUTO follows the window: spread only when landscape. */
enum class SpreadMode {
    OFF,
    AUTO,
    ON,
    ;

    fun isEnabled(landscape: Boolean): Boolean = when (this) {
        OFF -> false
        ON -> true
        AUTO -> landscape
    }

    companion object {
        fun fromStorage(value: String?): SpreadMode =
            value?.let { v -> entries.firstOrNull { it.name == v } } ?: OFF
    }
}
