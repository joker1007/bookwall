# frozen_string_literal: true

module Books
  class RefreshJob < ApplicationJob
    TARGETS = %w[reload_metadata regenerate_cover].freeze

    queue_as :default

    def perform(book_ids, target)
      raise ArgumentError, "unknown target: #{target}" unless TARGETS.include?(target.to_s)

      # Mirror the scanner: suppress per-row FTS enqueues and sync once at the end.
      previous_skip = Thread.current[:bookwall_skip_fts_callback]
      Thread.current[:bookwall_skip_fts_callback] = true

      refreshed_ids = []
      Book.where(id: book_ids).includes(:library).find_each do |book|
        Scanners::BookRefresher.new(book).public_send(:"#{target}!")
        refreshed_ids << book.id
      rescue StandardError => e
        Rails.logger.warn("[Books::RefreshJob] #{target} failed book=#{book.id}: #{e.message}")
      end

      Books::FtsSyncJob.perform_later(refreshed_ids, "upsert") if target.to_s == "reload_metadata" && refreshed_ids.any?
    ensure
      Thread.current[:bookwall_skip_fts_callback] = previous_skip
    end
  end
end
