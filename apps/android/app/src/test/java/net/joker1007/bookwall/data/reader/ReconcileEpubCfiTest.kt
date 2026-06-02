package net.joker1007.bookwall.data.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ReconcileEpubCfiTest {

    @Test
    fun `null when neither side has a position`() {
        assertNull(reconcileEpubCfi(null, null, null, null))
    }

    @Test
    fun `uses remote when local is absent`() {
        assertEquals("R", reconcileEpubCfi(null, null, "R", 0.5f))
    }

    @Test
    fun `uses local when remote is absent`() {
        assertEquals("L", reconcileEpubCfi("L", 0.5f, null, null))
    }

    @Test
    fun `picks the furthest by fraction`() {
        assertEquals("R", reconcileEpubCfi("L", 0.2f, "R", 0.8f))
        assertEquals("L", reconcileEpubCfi("L", 0.8f, "R", 0.2f))
    }

    @Test
    fun `local wins ties within epsilon`() {
        assertEquals("L", reconcileEpubCfi("L", 0.5f, "R", 0.5f))
        assertEquals("L", reconcileEpubCfi("L", 0.5f, "R", 0.5004f))
    }
}
