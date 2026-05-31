package net.joker1007.bookwall.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [OpdsServerEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class BookwallDatabase : RoomDatabase() {
    abstract fun opdsServerDao(): OpdsServerDao

    companion object {
        const val NAME = "bookwall.db"
    }
}
