package net.joker1007.bookwall.data.reader.local

import org.junit.Assert.assertEquals
import org.junit.Test

class NaturalOrderTest {
    // Vectors shared with server/spec/services/parsers_spec.rb.
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

    @Test
    fun `moves the first front-cover-named file to the front`() {
        val names = listOf(
            "10.jpg", "2.jpg", "back-cover.jpg", "表紙裏.jpg",
            "x/Cover.JPG", "discover.jpg", "covers/1.jpg", "表紙.jpg",
        )

        assertEquals(
            listOf(
                "x/Cover.JPG", "2.jpg", "10.jpg", "back-cover.jpg",
                "covers/1.jpg", "discover.jpg", "表紙.jpg", "表紙裏.jpg",
            ),
            NaturalOrder.orderPages(names),
        )
    }
}
