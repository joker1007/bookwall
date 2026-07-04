package net.joker1007.bookwall.data.reader.local

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@OptIn(ExperimentalCoroutinesApi::class)
class LocalBookSourceFactoryTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private val factory = LocalBookSourceFactory(UnconfinedTestDispatcher())

    private fun zipFile(name: String, entries: Map<String, ByteArray>): File {
        val file = tmp.newFile(name)
        ZipOutputStream(file.outputStream()).use { zip ->
            entries.forEach { (entryName, bytes) ->
                zip.putNextEntry(ZipEntry(entryName))
                zip.write(bytes)
                zip.closeEntry()
            }
        }
        return file
    }

    @Test
    fun `opens a cbz with pages in lowercased lexicographic entry order`() = runTest {
        // Deliberately out of insertion order + mixed case; matches the server's
        // name.downcase sort, so page numbers stay PSE-compatible.
        val file = zipFile(
            "book.cbz",
            linkedMapOf(
                "Pages/010.JPG" to byteArrayOf(1),
                "Pages/002.jpg" to byteArrayOf(2),
                "cover.png" to byteArrayOf(3),
                "notes.txt" to byteArrayOf(4),
            ),
        )

        val book = factory.open(file, mimeHint = "application/x-cbz") as LocalBook.Images
        val source = book.pageSource as LocalCbzPageSource

        assertEquals(3, source.pageCount)
        val pages = (0 until source.pageCount).map { (source.pageModel(it) as CbzPage) }
        assertEquals(listOf(0, 1, 2), pages.map { it.index })
        // Sorted lowercased: cover.png < pages/002.jpg < pages/010.jpg.
        assertEquals(byteArrayOf(3).toList(), source.openPage(0).use { it.readBytes() }.toList())
        assertEquals(byteArrayOf(2).toList(), source.openPage(1).use { it.readBytes() }.toList())
        assertEquals(byteArrayOf(1).toList(), source.openPage(2).use { it.readBytes() }.toList())
        source.close()
    }

    @Test
    fun `detects an epub by extension`() = runTest {
        val file = zipFile("book.epub", mapOf("mimetype" to "application/epub+zip".toByteArray()))

        assertTrue(factory.open(file) is LocalBook.Epub)
    }

    @Test
    fun `sniffs an extension-less epub via its mimetype entry`() = runTest {
        val file = zipFile("mystery.bin", mapOf("mimetype" to "application/epub+zip".toByteArray()))

        assertTrue(factory.open(file) is LocalBook.Epub)
    }

    @Test
    fun `sniffs an extension-less zip of images as cbz`() = runTest {
        val file = zipFile("mystery2.bin", mapOf("001.jpg" to byteArrayOf(1)))

        val book = factory.open(file)
        assertTrue(book is LocalBook.Images)
        (book as LocalBook.Images).pageSource.close()
    }

    @Test
    fun `mime hint wins over a misleading extension`() = runTest {
        val file = zipFile("misnamed.epub", mapOf("001.jpg" to byteArrayOf(1)))

        val book = factory.open(file, mimeHint = "application/x-cbz")
        assertTrue(book is LocalBook.Images)
        (book as LocalBook.Images).pageSource.close()
    }
}
