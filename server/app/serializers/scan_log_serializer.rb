# frozen_string_literal: true

class ScanLogSerializer
  include Alba::Resource

  attributes :id, :library_id, :status, :started_at, :finished_at,
    :found_count, :added_count, :updated_count, :removed_count,
    :error_message

  # Live progress for an in-flight scan. The scanner flushes
  # `{ processed:, total: }` into Rails.cache every 10 books, so this
  # is at most 10 books behind reality. Reflects 0 / nil for scans
  # that aren't currently running.
  attribute :processed_count do |log|
    next nil unless log.running?
    cached = Rails.cache.read(Scanners::LibraryScanner.progress_cache_key(log.id))
    cached&.dig(:processed) || 0
  end
end
