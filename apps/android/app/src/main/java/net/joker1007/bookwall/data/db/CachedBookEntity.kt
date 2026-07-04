package net.joker1007.bookwall.data.db

import androidx.room.Entity

enum class CachedBookStatus { PENDING, DOWNLOADING, COMPLETED, FAILED }

/**
 * A book file cached on local storage for offline reading. Keyed by
 * (serverId, bookId) like reader_states, so a book cached from one feed path
 * (series, tag, favorites...) is recognized on every other path.
 */
@Entity(tableName = "cached_books", primaryKeys = ["serverId", "bookId"])
data class CachedBookEntity(
    val serverId: Long,
    val bookId: Long,
    // Metadata kept locally so the downloads screen works fully offline.
    val title: String,
    val authors: String,
    val format: String?,
    val pageCount: Int,
    // Paths relative to the cache root (see BookCacheFileStore).
    val fileName: String,
    val thumbnailFileName: String?,
    val status: CachedBookStatus,
    val downloadedBytes: Long,
    /** Expected size from the feed's length attribute or Content-Length; 0 = unknown. */
    val totalBytes: Long,
    val retryCount: Int,
    /** Absolute acquisition URL resolved at enqueue time. */
    val acquisitionUrl: String,
    val thumbnailUrl: String?,
    val createdAt: Long,
    /** Bumped when the cached file is opened; drives LRU eviction. */
    val lastAccessedAt: Long,
)
