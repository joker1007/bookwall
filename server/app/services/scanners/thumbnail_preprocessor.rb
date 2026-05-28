# frozen_string_literal: true

module Scanners
  # Bulk-generates the :thumb variant for every book the scan touched so its
  # active_storage_variant_record exists before the web side ever asks for the
  # thumbnail URL. Without this, a 200-cover grid view would trigger 200
  # parallel INSERT bursts against SQLite's single writer under request load.
  # Idempotent — `.processed` no-ops when the variant_record already exists.
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

      # Cap workers at the AR pool size so we don't block waiting on connection
      # checkouts — each .processed call grabs a connection to write the
      # variant_record row.
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
