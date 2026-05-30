# frozen_string_literal: true

require "etc"

module Scanners
  class LibraryScanner
    include SqliteRetryable

    # Floor of 2 so single-core hosts still overlap parse + hash.
    DEFAULT_POOL_SIZE = ENV.fetch("BOOKWALL_SCAN_POOL_SIZE") { [Etc.nprocessors, 2].max }.to_i

    # Each flush is a Solid Cache write (SQLite), so batch rather than flush per book.
    PROGRESS_FLUSH_EVERY = 10
    PROGRESS_CACHE_TTL = 1.hour

    attr_reader :library

    def initialize(library, pool_size: DEFAULT_POOL_SIZE)
      @library = library
      @pool_size = pool_size
    end

    def call
      # Suppress Book#after_commit's per-row FTS enqueue; replaced by one bulk job at the end.
      previous_skip = Thread.current[:bookwall_skip_fts_callback]
      Thread.current[:bookwall_skip_fts_callback] = true

      log = library.scan_logs.create!(status: :running, started_at: Time.current)
      jobs = Scanners::LibraryDiscovery.new(library.path).call.freeze
      diff = Scanners::LibraryDiff.new(library).call(jobs)

      log.update_columns(
        found_count: jobs.size,
        added_count: diff[:add].size,
        updated_count: diff[:update].size,
        removed_count: 0
      )

      # Pruning of vanished files is intentionally left to a separate cleanup job.
      total = diff[:add].size + diff[:update].size
      upserted_ids = parse_and_apply(diff[:add] + diff[:update], scan_log_id: log.id, total: total)

      Scanners::ThumbnailPreprocessor.new(pool_size: @pool_size).call(upserted_ids)

      library.update!(last_scanned_at: Time.current)
      log.update!(status: :succeeded, finished_at: Time.current)
      Rails.cache.delete(progress_cache_key(log.id))

      enqueue_fts_sync(upserted_ids)
      log
    rescue StandardError => e
      log&.update!(
        status: :failed,
        finished_at: Time.current,
        error_message: e.message
      )
      Rails.cache.delete(progress_cache_key(log.id)) if log
      raise
    ensure
      Thread.current[:bookwall_skip_fts_callback] = previous_skip
    end

    def self.progress_cache_key(scan_log_id)
      "scan_progress:#{scan_log_id}"
    end

    private

    def enqueue_fts_sync(upserted_ids)
      return if upserted_ids.empty?
      Books::FtsSyncJob.perform_later(upserted_ids, "upsert")
    end

    # Parses files on a worker pool while the main thread consumes the queue and writes,
    # overlapping parse and write time. Returns the ids of created/updated books.
    def parse_and_apply(jobs, scan_log_id: nil, total: nil)
      return [] if jobs.empty?

      pool_size = [@pool_size, jobs.size].min
      pool = Concurrent::FixedThreadPool.new(pool_size)
      result_q = Queue.new

      jobs.each do |job|
        pool.post { result_q.push(Scanners::ParseWorker.parse(job)) }
      end

      upserted_ids = []
      processed = 0
      begin
        jobs.size.times do
          result = result_q.pop
          processed += 1
          if !result[:error]
            book = with_busy_retry do
              ActiveRecord::Base.transaction { upsert_book(result) }
            end
            upserted_ids << book.id if book
          end
          if scan_log_id && (processed % PROGRESS_FLUSH_EVERY).zero?
            write_progress(scan_log_id, processed, total)
          end
        end
        write_progress(scan_log_id, processed, total) if scan_log_id
        upserted_ids
      ensure
        pool.shutdown
        pool.wait_for_termination(60)
      end
    end

    def write_progress(scan_log_id, processed, total)
      Rails.cache.write(
        progress_cache_key(scan_log_id),
        {processed: processed, total: total},
        expires_in: PROGRESS_CACHE_TTL
      )
    end

    def progress_cache_key(scan_log_id)
      self.class.progress_cache_key(scan_log_id)
    end

    def upsert_book(result)
      meta = result[:metadata]
      author_records = upsert_named(Author, meta[:authors])
      tag_records = upsert_named(Tag, meta[:tags])
      series_name = meta[:series].presence || fallback_series_from_path(result[:path])
      series_record = ensure_series(series_name)

      relative_path = relative_to_library(result[:path])
      book = library.books.find_or_initialize_by(file_path: relative_path)
      book.assign_attributes(
        series: series_record,
        title: meta[:title].presence || File.basename(result[:path], ".*"),
        volume: meta[:volume],
        file_format: result[:format],
        file_size: result[:file_size],
        page_count: meta[:page_count],
        published_at: meta[:published_at],
        scanned_at: Time.current
      )
      book.save!
      book.authors = author_records
      book.tags = tag_records
      Covers::Extractor.attach(book, result[:cover_bytes])
      book
    end

    def upsert_named(model, names)
      return [] if names.blank?
      cleaned = names.map(&:to_s).map(&:strip).reject(&:empty?).uniq
      return [] if cleaned.empty?
      model.upsert_all(cleaned.map { |n| {name: n} }, unique_by: :name)
      model.where(name: cleaned).to_a
    end

    def ensure_series(name)
      return nil if name.blank?
      library.series.find_or_create_by!(name: name)
    end

    # Books at the library root get no series; the root dir is not a series.
    def fallback_series_from_path(path)
      parent = File.expand_path(File.dirname(path))
      return nil if parent == library_root
      File.basename(parent).presence
    end

    # Paths outside the library root are returned unchanged to surface the misconfiguration.
    def relative_to_library(path)
      absolute = File.expand_path(path)
      prefix = "#{library_root}/"
      return absolute unless absolute.start_with?(prefix)
      absolute[prefix.length..]
    end

    def library_root
      @library_root ||= File.expand_path(library.path)
    end
  end
end
