package net.joker1007.bookwall.data.db

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * Hand-written migrations. Destructive fallback is kept only as a last resort;
 * dropping tables would orphan cached book files, so schema changes from v5 on
 * must migrate.
 */
val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS `cached_books` (
                `serverId` INTEGER NOT NULL,
                `bookId` INTEGER NOT NULL,
                `title` TEXT NOT NULL,
                `authors` TEXT NOT NULL,
                `format` TEXT,
                `pageCount` INTEGER NOT NULL,
                `fileName` TEXT NOT NULL,
                `thumbnailFileName` TEXT,
                `status` TEXT NOT NULL,
                `downloadedBytes` INTEGER NOT NULL,
                `totalBytes` INTEGER NOT NULL,
                `retryCount` INTEGER NOT NULL,
                `acquisitionUrl` TEXT NOT NULL,
                `thumbnailUrl` TEXT,
                `createdAt` INTEGER NOT NULL,
                `lastAccessedAt` INTEGER NOT NULL,
                PRIMARY KEY(`serverId`, `bookId`)
            )
            """.trimIndent(),
        )
        db.execSQL("ALTER TABLE `reader_states` ADD COLUMN `dirty` INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE `epub_progress` ADD COLUMN `dirty` INTEGER NOT NULL DEFAULT 0")
    }
}

val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE `cached_books` ADD COLUMN `etag` TEXT")
    }
}

val ALL_MIGRATIONS = arrayOf(MIGRATION_5_6, MIGRATION_6_7)
