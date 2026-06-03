# frozen_string_literal: true

module Scanners
  # Pre-creates :thumb variant_records during the scan so a cover grid view doesn't
  # trigger a burst of INSERTs against SQLite's single writer under request load.
  class ThumbnailPreprocessor
    include SqliteRetryable

    # Runs serially: each .processed ends in a variant_record INSERT, and SQLite
    # serializes writers regardless of WAL, so parallel workers only contend on
    # the single write lock. A plain loop sidesteps that contention entirely.
    def call(book_ids)
      return if book_ids.empty?

      books = Book.where(id: book_ids).with_attached_cover.to_a
      books.select! { |b| b.cover.attached? }

      books.each do |book|
        with_busy_retry { book.cover.variant(:thumb).processed }
      rescue StandardError => e
        Rails.logger.warn do
          "[ThumbnailPreprocessor] thumb preprocess failed book=#{book.id}: #{e.message}"
        end
      end
    end
  end
end
