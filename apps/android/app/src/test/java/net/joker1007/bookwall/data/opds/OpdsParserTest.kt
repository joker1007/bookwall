package net.joker1007.bookwall.data.opds

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.kxml2.io.KXmlParser
import org.xmlpull.v1.XmlPullParser
import java.io.StringReader

class OpdsParserTest {

    private val parser = OpdsParser()

    private fun parse(xml: String): OpdsFeed {
        val pull = KXmlParser().apply {
            setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
            setInput(StringReader(xml))
        }
        return parser.parse(pull)
    }

    @Test
    fun `parses a navigation feed`() {
        val feed = parse(NAVIGATION_FEED)

        assertEquals("Bookwall", feed.title)
        assertEquals("urn:bookwall:root", feed.id)
        assertEquals("/opds", feed.selfHref)
        assertFalse(feed.isAcquisition)
        assertEquals(2, feed.entries.size)

        val first = feed.entries[0]
        assertTrue(first is OpdsEntry.Navigation)
        first as OpdsEntry.Navigation
        assertEquals("Recent", first.title)
        assertEquals("/opds/recent", first.href)
    }

    @Test
    fun `parses an acquisition feed with facets`() {
        val feed = parse(ACQUISITION_FEED)

        assertTrue(feed.isAcquisition)
        assertEquals(1, feed.facets.size)
        val facet = feed.facets.single()
        assertEquals("SciFi", facet.title)
        assertEquals("Tags", facet.group)
        assertEquals(5, facet.count)
        assertTrue(facet.active)
    }

    @Test
    fun `parses a comic book entry with pse and thumbnail`() {
        val feed = parse(ACQUISITION_FEED)
        val book = feed.entries[0] as OpdsEntry.Book

        assertEquals("Book One", book.title)
        assertEquals("urn:bookwall:book:42", book.id)
        assertEquals(listOf("Author A"), book.authors)
        assertEquals(listOf("SciFi", "Action"), book.tags)
        assertEquals("ja", book.language)
        assertEquals("/opds/books/42/file.cbz", book.acquisitionHref)
        assertEquals("/rails/blob/cover.jpg", book.imageHref)
        assertEquals("/rails/rep/thumb.jpg", book.thumbnailHref)

        val pse = requireNotNull(book.pse)
        assertEquals(120, pse.pageCount)
        assertEquals(10, pse.lastRead)
        assertTrue(pse.streamHrefTemplate.contains(OpdsParser.PSE_PAGE_TOKEN))
    }

    @Test
    fun `epub entry has no pse stream`() {
        val feed = parse(ACQUISITION_FEED)
        val epub = feed.entries[1] as OpdsEntry.Book

        assertEquals("application/epub+zip", epub.format)
        assertEquals("/opds/books/43/file.epub", epub.acquisitionHref)
        assertNull(epub.pse)
        assertNull(epub.thumbnailHref)
    }

    private companion object {
        val NAVIGATION_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog">
              <title>Bookwall</title>
              <id>urn:bookwall:root</id>
              <updated>2026-01-01T00:00:00Z</updated>
              <link rel="self" href="/opds" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              <link rel="start" href="/opds/recent" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              <entry>
                <title>Recent</title>
                <id>urn:bookwall:nav:Recent</id>
                <updated>2026-01-01T00:00:00Z</updated>
                <link rel="subsection" href="/opds/recent" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
              </entry>
              <entry>
                <title>Series</title>
                <id>urn:bookwall:nav:Series</id>
                <updated>2026-01-01T00:00:00Z</updated>
                <link rel="subsection" href="/opds/series" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
              </entry>
            </feed>
        """.trimIndent()

        val ACQUISITION_FEED = """
            <?xml version="1.0" encoding="UTF-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom"
                  xmlns:opds="http://opds-spec.org/2010/catalog"
                  xmlns:pse="http://vaemendis.net/opds-pse/ns"
                  xmlns:dc="http://purl.org/dc/elements/1.1/"
                  xmlns:thr="http://purl.org/syndication/thread/1.0">
              <title>Recent</title>
              <id>urn:bookwall:recent</id>
              <updated>2026-01-01T00:00:00Z</updated>
              <link rel="self" href="/opds/recent" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
              <link rel="http://opds-spec.org/facet" href="/opds/recent?tag_id=1" title="SciFi" opds:facetGroup="Tags" thr:count="5" opds:activeFacet="true"/>
              <entry>
                <title>Book One</title>
                <id>urn:bookwall:book:42</id>
                <updated>2026-01-01T00:00:00Z</updated>
                <author><name>Author A</name></author>
                <dc:language>ja</dc:language>
                <dc:format>application/vnd.comicbook+zip</dc:format>
                <category term="SciFi"/>
                <category term="Action"/>
                <content type="text">CBZ · 120 pages</content>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/42/file.cbz" type="application/vnd.comicbook+zip"/>
                <link rel="http://opds-spec.org/image" href="/rails/blob/cover.jpg" type="image/jpeg"/>
                <link rel="http://opds-spec.org/image/thumbnail" href="/rails/rep/thumb.jpg" type="image/jpeg"/>
                <pse:link rel="http://vaemendis.net/opds-pse/stream" href="/opds/books/42/pages/{pageNumber}" type="image/jpeg" pse:count="120" pse:lastRead="10" pse:lastReadDate="2026-01-01T00:00:00Z"/>
              </entry>
              <entry>
                <title>Reflowable Book</title>
                <id>urn:bookwall:book:43</id>
                <updated>2026-01-01T00:00:00Z</updated>
                <dc:format>application/epub+zip</dc:format>
                <content type="text">EPUB</content>
                <link rel="http://opds-spec.org/acquisition" href="/opds/books/43/file.epub" type="application/epub+zip"/>
                <link rel="http://opds-spec.org/image" href="/rails/blob/cover2.jpg" type="image/jpeg"/>
              </entry>
            </feed>
        """.trimIndent()
    }
}
