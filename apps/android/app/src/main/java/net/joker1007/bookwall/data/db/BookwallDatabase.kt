package net.joker1007.bookwall.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        OpdsServerEntity::class,
        ReaderStateEntity::class,
        EpubProgressEntity::class,
        CachedBookEntity::class,
    ],
    version = 7,
    exportSchema = false,
)
abstract class BookwallDatabase : RoomDatabase() {
    abstract fun opdsServerDao(): OpdsServerDao

    abstract fun readerStateDao(): ReaderStateDao

    abstract fun epubProgressDao(): EpubProgressDao

    abstract fun cachedBookDao(): CachedBookDao

    companion object {
        const val NAME = "bookwall.db"
    }
}
