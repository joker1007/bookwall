# frozen_string_literal: true

module Cleanup
  # Prunes metadata whose backing data is gone: books whose files have
  # disappeared from disk, then the tags/authors left carrying no books.
  # Files on disk are never touched — only the records.
  #
  # Books must be processed first because destroying a book cascades its
  # BookTag / BookAuthor joins, which is exactly what leaves a tag/author
  # orphaned for the subsequent passes to sweep up.
  class OrphanCleaner
    Result = Struct.new(:removed_books, :removed_tags, :removed_authors, keyword_init: true)

    def call
      removed_book_ids = remove_missing_file_books
      result = Result.new(
        removed_books: removed_book_ids.size,
        removed_tags: remove_orphaned_tags,
        removed_authors: remove_orphaned_authors
      )
      Rails.logger.info(
        "[Cleanup::OrphanCleaner] removed books=#{result.removed_books} " \
        "tags=#{result.removed_tags} authors=#{result.removed_authors}"
      )
      result
    end

    private

    def remove_missing_file_books
      removed_ids = []
      # Suppress Book#after_commit's per-row FTS delete; collect the ids and
      # enqueue a single bulk delete at the end so SQLite's writer lock is
      # exercised once, mirroring the scanner.
      previous_skip = Thread.current[:bookwall_skip_fts_callback]
      Thread.current[:bookwall_skip_fts_callback] = true
      begin
        Library.find_each do |library|
          # If the library root itself is unavailable (e.g. an unmounted
          # drive) skip it wholesale, so a temporarily missing mount can't
          # mass-delete every book under it.
          next unless Dir.exist?(library.path)

          library.books.find_each do |book|
            next if File.exist?(book.absolute_path)
            book.destroy!
            removed_ids << book.id
          end
        end
      ensure
        Thread.current[:bookwall_skip_fts_callback] = previous_skip
      end
      Books::FtsSyncJob.perform_later(removed_ids, "delete") if removed_ids.any?
      removed_ids
    end

    def remove_orphaned_tags
      Tag.where.missing(:book_tags).delete_all
    end

    def remove_orphaned_authors
      Author.where.missing(:book_authors).delete_all
    end
  end
end
