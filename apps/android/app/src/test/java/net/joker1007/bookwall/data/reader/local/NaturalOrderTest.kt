package net.joker1007.bookwall.data.reader.local

import org.junit.Assert.assertEquals
import org.junit.Test

class NaturalOrderTest {
    // Same vector as server/spec/services/parsers_spec.rb (.natural_sort).
    @Test
    fun `sorts digit runs numerically and case-insensitively`() {
        val names = listOf(
            "Page10.jpg", "page2.jpg", "page1.jpg", "page01.jpg", "Page1.jpg",
            "ch10/001.jpg", "ch2/010.jpg", "ch2/2.jpg", "cover.jpg", "a.jpg",
        )

        assertEquals(
            listOf(
                "a.jpg", "ch2/2.jpg", "ch2/010.jpg", "ch10/001.jpg", "cover.jpg",
                "Page1.jpg", "page01.jpg", "page1.jpg", "page2.jpg", "Page10.jpg",
            ),
            names.sortedWith(NaturalOrder),
        )
    }
}
