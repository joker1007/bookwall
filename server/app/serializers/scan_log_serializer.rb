# frozen_string_literal: true

class ScanLogSerializer
  include Alba::Resource

  attributes :id, :library_id, :status, :started_at, :finished_at,
    :found_count, :added_count, :updated_count, :removed_count,
    :error_message

  # Cache is flushed every 10 books, so this lags reality by up to 10.
  attribute :processed_count do |log|
    next nil unless log.running?
    cached = Rails.cache.read(Scanners::LibraryScanner.progress_cache_key(log.id))
    cached&.dig(:processed) || 0
  end
end
