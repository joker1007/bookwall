package net.joker1007.bookwall.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [OpdsServerEntity::class, ReaderStateEntity::class, EpubProgressEntity::class],
    version = 3,
    exportSchema = false,
)
abstract class BookwallDatabase : RoomDatabase() {
    abstract fun opdsServerDao(): OpdsServerDao

    abstract fun readerStateDao(): ReaderStateDao

    abstract fun epubProgressDao(): EpubProgressDao

    companion object {
        const val NAME = "bookwall.db"
    }
}
