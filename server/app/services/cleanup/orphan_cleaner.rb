# frozen_string_literal: true

module Cleanup
  # Books must be pruned before tags/authors: destroying a book cascades its
  # join rows, which is what leaves the tags/authors orphaned for later passes.
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
      # Suppress per-row FTS callback; do a single bulk delete to hit SQLite's writer lock once.
      previous_skip = Thread.current[:bookwall_skip_fts_callback]
      Thread.current[:bookwall_skip_fts_callback] = true
      begin
        Library.find_each do |library|
          # Skip an unavailable root (e.g. unmounted drive) so it can't mass-delete every book under it.
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
