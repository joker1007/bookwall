package net.joker1007.bookwall.data.reader

/** Default page jump for the "continuous" tap actions. */
const val CONTINUOUS_PAGE_STEP = 5

/** Action performed when a tap zone is tapped. */
enum class TapAction {
    NONE,
    TOGGLE_MENU,
    PREVIOUS,
    NEXT,

    /** Step exactly one page, even in spread mode (offset realignment). */
    PREVIOUS_SINGLE,
    NEXT_SINGLE,

    /** Jump several pages at once. */
    PREVIOUS_CONTINUOUS,
    NEXT_CONTINUOUS,
}

/** Horizontal screen regions that receive taps. */
enum class TapZone { LEFT, CENTER, RIGHT }

/**
 * Maps physical tap zones to reading actions. Zones are physical (left/center/
 * right of the screen); actions are reading-order, so RTL is handled by the
 * pager's reverse layout, not by remapping zones.
 */
data class TapZoneConfig(
    val left: TapAction = TapAction.PREVIOUS,
    val center: TapAction = TapAction.TOGGLE_MENU,
    val right: TapAction = TapAction.NEXT,
) {
    fun actionFor(zone: TapZone): TapAction = when (zone) {
        TapZone.LEFT -> left
        TapZone.CENTER -> center
        TapZone.RIGHT -> right
    }

    fun with(zone: TapZone, action: TapAction): TapZoneConfig = when (zone) {
        TapZone.LEFT -> copy(left = action)
        TapZone.CENTER -> copy(center = action)
        TapZone.RIGHT -> copy(right = action)
    }
}

/**
 * Resolves the page a tap [action] should move to, given the current slots and
 * page. Returns null when the action does not move pages (menu toggle / none).
 * Callers clamp the result via the reader's goToPage.
 */
fun tapTargetPage(
    action: TapAction,
    slots: List<List<Int>>,
    currentPage: Int,
    continuousStep: Int = CONTINUOUS_PAGE_STEP,
): Int? {
    val currentSlot = slotIndexForPage(slots, currentPage)
    return when (action) {
        TapAction.NEXT -> slots.getOrNull(currentSlot + 1)?.firstOrNull() ?: currentPage
        TapAction.PREVIOUS -> slots.getOrNull(currentSlot - 1)?.firstOrNull() ?: currentPage
        TapAction.NEXT_SINGLE -> currentPage + 1
        TapAction.PREVIOUS_SINGLE -> currentPage - 1
        TapAction.NEXT_CONTINUOUS -> currentPage + continuousStep
        TapAction.PREVIOUS_CONTINUOUS -> currentPage - continuousStep
        TapAction.TOGGLE_MENU, TapAction.NONE -> null
    }
}
