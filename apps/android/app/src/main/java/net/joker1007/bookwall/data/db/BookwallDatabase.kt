package net.joker1007.bookwall.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [OpdsServerEntity::class, ReaderStateEntity::class],
    version = 2,
    exportSchema = false,
)
abstract class BookwallDatabase : RoomDatabase() {
    abstract fun opdsServerDao(): OpdsServerDao

    abstract fun readerStateDao(): ReaderStateDao

    companion object {
        const val NAME = "bookwall.db"
    }
}
