# frozen_string_literal: true

module Scanners
  # Pre-creates :thumb variant_records during the scan so a cover grid view doesn't
  # trigger a burst of INSERTs against SQLite's single writer under request load.
  class ThumbnailPreprocessor
    include SqliteRetryable

    def initialize(pool_size:)
      @pool_size = pool_size
    end

    def call(book_ids)
      return if book_ids.empty?

      books = Book.where(id: book_ids).with_attached_cover.to_a
      books.select! { |b| b.cover.attached? }
      return if books.empty?

      # Cap workers at the AR pool size; each .processed checks out a connection.
      pool_size = [@pool_size, books.size, ActiveRecord::Base.connection_pool.size].min
      pool_size = 1 if pool_size < 1
      pool = Concurrent::FixedThreadPool.new(pool_size)

      books.each do |book|
        pool.post do
          ActiveRecord::Base.connection_pool.with_connection do
            with_busy_retry { book.cover.variant(:thumb).processed }
          end
        rescue StandardError => e
          Rails.logger.warn do
            "[ThumbnailPreprocessor] thumb preprocess failed book=#{book.id}: #{e.message}"
          end
        end
      end

      pool.shutdown
      pool.wait_for_termination
    end
  end
end
