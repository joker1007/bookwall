# frozen_string_literal: true

require "find"
require "retriable"

module Scanners
  class LibraryScanner
    DEFAULT_POOL_SIZE = ENV.fetch("BOOKWALL_SCAN_POOL_SIZE", 4).to_i

    # ActiveRecord::StatementInvalid whose message (or wrapped cause) matches
    # one of these patterns means SQLite returned BUSY — the writer can retry
    # safely. Other StatementInvalid causes (constraint violations etc.) are
    # not retried.
    SQLITE_BUSY_PATTERN = /database is locked|SQLITE_BUSY|SQLite3::BusyException/

    attr_reader :library

    def initialize(library, pool_size: DEFAULT_POOL_SIZE)
      @library = library
      @pool_size = pool_size
    end

    def call
      # Suppress Book#after_commit's per-row FTS enqueue during the scan;
      # we collect the touched ids and enqueue a single bulk job at the
      # end so SQLite's writer lock is exercised once, not N times.
      previous_skip = Thread.current[:bookwall_skip_fts_callback]
      Thread.current[:bookwall_skip_fts_callback] = true

      log = library.scan_logs.create!(status: :running, started_at: Time.current)
      jobs = discover(library.path).freeze
      diff = diff_against_db(jobs)

      # The scan no longer prunes books whose files have disappeared. That
      # work belongs to a dedicated cleanup job (to be added) so the scan
      # only does add / update writes and keeps the writer-lock window
      # short.
      results = parse_parallel(diff[:add] + diff[:update])
      upserted_ids = apply_results(results)

      library.update!(last_scanned_at: Time.current)
      log.update!(
        status: :succeeded,
        finished_at: Time.current,
        found_count: jobs.size,
        added_count: diff[:add].size,
        updated_count: diff[:update].size,
        removed_count: 0
      )

      enqueue_fts_sync(upserted_ids)
      log
    rescue StandardError => e
      log&.update!(
        status: :failed,
        finished_at: Time.current,
        error_message: e.message
      )
      raise
    ensure
      Thread.current[:bookwall_skip_fts_callback] = previous_skip
    end

    private

    def enqueue_fts_sync(upserted_ids)
      return if upserted_ids.empty?
      Books::FtsSyncJob.perform_later(upserted_ids, "upsert")
    end

    def discover(root)
      out = []
      Find.find(root) do |path|
        next if path == root
        basename = File.basename(path)
        Find.prune if basename.start_with?(".")

        if File.directory?(path)
          if image_dir?(path)
            out << {path: path.dup.freeze, format: :image_dir}.freeze
            Find.prune
          end
        else
          fmt = format_from_extension(path)
          out << {path: path.dup.freeze, format: fmt}.freeze if fmt
        end
      end
      out
    end

    def format_from_extension(path)
      case File.extname(path).downcase
      when ".cbz" then :cbz
      when ".epub" then :epub
      when ".pdf" then :pdf
      end
    end

    def image_dir?(dir)
      Dir.children(dir).any? do |f|
        Parsers::IMAGE_EXTENSIONS.include?(File.extname(f).downcase)
      end
    end

    def diff_against_db(jobs)
      # Files on disk are seen as absolute paths during discovery, but
      # the DB now holds them library-relative. Re-absolutise the DB
      # rows for the comparison so existing-record lookup still works.
      root = File.expand_path(library.path)
      existing = library.books.pluck(:file_path, :scanned_at).to_h do |rel, scanned_at|
        [File.expand_path(File.join(root, rel)), scanned_at]
      end

      to_add = []
      to_update = []
      jobs.each do |job|
        scanned_at = existing[job[:path]]
        if scanned_at.nil?
          to_add << job
        elsif modified_since?(job[:path], scanned_at)
          to_update << job
        end
      end

      # Deleted files are handled by a separate cleanup job; the scan
      # itself only adds and updates.
      {add: to_add, update: to_update}
    end

    def modified_since?(path, scanned_at)
      mtime =
        if File.directory?(path)
          times = Dir.children(path).map { |f| File.mtime(File.join(path, f)) }
          times.max || Time.at(0)
        else
          File.mtime(path)
        end
      mtime > scanned_at
    end

    def parse_parallel(jobs)
      return [] if jobs.empty?
      size = [@pool_size, jobs.size].min
      pool = Concurrent::FixedThreadPool.new(size)
      begin
        futures = jobs.map do |job|
          Concurrent::Future.execute(executor: pool) { Scanners::ParseWorker.parse(job) }
        end
        futures.map(&:value!)
      ensure
        pool.shutdown
        pool.wait_for_termination(30)
      end
    end

    # Returns the ids of books that were created or updated so the caller
    # can dispatch the FTS sync in bulk. Each book's writes (taxonomy
    # upserts, the book row, join replacements, and the cover attachment)
    # run inside a single transaction so the SQLite writer lock is
    # acquired once per book rather than once per statement, and so the
    # whole set rolls back together on failure.
    def apply_results(results)
      results.filter_map do |result|
        next if result[:error]
        with_busy_retry do
          ActiveRecord::Base.transaction { upsert_book(result) }
        end&.id
      end
    end

    # Wrap a SQLite write block so it survives transient BUSY errors from
    # other writers (e.g. the web process committing favorites or reading
    # progress while the scanner is also writing). The driver already
    # honors busy_timeout; this adds an application-level retry on top so
    # very long contention windows still succeed instead of failing the
    # whole scan.
    def with_busy_retry(&block)
      Retriable.retriable(
        on: {ActiveRecord::StatementInvalid => SQLITE_BUSY_PATTERN},
        tries: 5,
        base_interval: 0.1,
        multiplier: 2.0,
        rand_factor: 0.25,
        on_retry: ->(exception, try, _elapsed, next_interval) {
          # On the final failure Retriable passes next_interval == nil.
          delay_text = next_interval ? "after #{next_interval.round(2)}s" : "(no more retries)"
          Rails.logger.warn do
            "[LibraryScanner] SQLite busy, retry #{try} #{delay_text}: #{exception.message}"
          end
        },
        &block
      )
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
        file_hash: result[:file_hash],
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

    # When a book carries no series metadata of its own, fall back to the
    # name of the directory containing it — e.g. `<library>/Akira/vol1.cbz`
    # joins the "Akira" series. Books sitting at the library root get no
    # series, since the root directory isn't a series in any meaningful
    # sense.
    def fallback_series_from_path(path)
      parent = File.expand_path(File.dirname(path))
      return nil if parent == library_root
      File.basename(parent).presence
    end

    # Strip the library root prefix off an absolute discovered path so we
    # can store it relative in the DB. Anything that doesn't sit under
    # the library root is returned unchanged — that's a configuration
    # bug worth surfacing rather than papering over.
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
