# frozen_string_literal: true

require "etc"
require "retriable"

module Scanners
  class LibraryScanner
    # One worker per CPU core, with a floor of 2 so single-core hosts
    # still get parser + hash overlap. Override with BOOKWALL_SCAN_POOL_SIZE.
    DEFAULT_POOL_SIZE = ENV.fetch("BOOKWALL_SCAN_POOL_SIZE") { [Etc.nprocessors, 2].max }.to_i

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

      # Surface totals to the UI as soon as we know them so the
      # progress indicator can show "X / Y" while parse_and_apply
      # runs. found_count is also useful even if there's nothing to
      # add or update.
      log.update_columns(
        found_count: jobs.size,
        added_count: diff[:add].size,
        updated_count: diff[:update].size,
        removed_count: 0
      )

      # The scan no longer prunes books whose files have disappeared. That
      # work belongs to a dedicated cleanup job (to be added) so the scan
      # only does add / update writes and keeps the writer-lock window
      # short.
      total = diff[:add].size + diff[:update].size
      upserted_ids = parse_and_apply(diff[:add] + diff[:update], scan_log_id: log.id, total: total)

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

    private

    def enqueue_fts_sync(upserted_ids)
      return if upserted_ids.empty?
      Books::FtsSyncJob.perform_later(upserted_ids, "upsert")
    end

    BOOK_FORMAT_GLOBS = {
      cbz: "**/*.cbz",
      epub: "**/*.epub",
      pdf: "**/*.pdf"
    }.freeze
    IMAGE_FORMAT_GLOBS = Parsers::IMAGE_EXTENSIONS.map { |ext| "**/*#{ext}" }.freeze

    # Discover all books under the library root using two C-level
    # globs:
    #   1. Find every image file and treat its parent directory as an
    #      image_dir book. Replaces the per-directory `Dir.children`
    #      check that the old `Find.find`-based walker did.
    #   2. Find every CBZ / EPUB / PDF. Files that live inside an
    #      already-identified image_dir are skipped so the
    #      "image_dir wins, prune everything below it" semantics of
    #      the old walker is preserved.
    # `File::FNM_CASEFOLD` matches `.JPG` / `.EPUB` etc. so users
    # don't have to normalise their library by hand.
    def discover(root)
      root = File.expand_path(root)

      image_dirs = collect_image_dirs(root)
      jobs = image_dirs.map do |dir|
        # mtime is left nil and resolved lazily in diff_against_db
        # only when an existing row needs to be compared — first-scan
        # image dirs avoid the per-child stat.
        {path: dir.freeze, format: :image_dir, mtime: nil}.freeze
      end

      BOOK_FORMAT_GLOBS.each do |fmt, pattern|
        Dir.glob(pattern, File::FNM_CASEFOLD, base: root) do |rel|
          next if hidden_path?(rel)
          full = File.join(root, rel)
          next if inside_image_dir?(full, image_dirs)
          stat = begin
            File.stat(full)
          rescue SystemCallError
            next
          end
          next unless stat.file?
          jobs << {path: full.freeze, format: fmt, mtime: stat.mtime}.freeze
        end
      end

      jobs
    end

    def collect_image_dirs(root)
      dirs = Set.new
      IMAGE_FORMAT_GLOBS.each do |pattern|
        Dir.glob(pattern, File::FNM_CASEFOLD, base: root) do |rel|
          next if hidden_path?(rel)
          parent_rel = File.dirname(rel)
          # Library root itself is never a book, even if loose images
          # got dropped there.
          next if parent_rel == "."
          dirs << File.join(root, parent_rel)
        end
      end
      dirs
    end

    def hidden_path?(rel)
      rel.split(File::SEPARATOR).any? { |seg| seg.start_with?(".") }
    end

    def inside_image_dir?(path, image_dirs)
      image_dirs.any? { |d| path.start_with?("#{d}/") }
    end

    def max_child_mtime(dir)
      best = nil
      Dir.each_child(dir) do |name|
        m = File.mtime(File.join(dir, name))
      rescue Errno::ENOENT, SystemCallError
        next
      else
        best = m if best.nil? || m > best
      end
      best || Time.at(0)
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
        else
          mtime = job[:mtime] || max_child_mtime(job[:path])
          to_update << job if mtime > scanned_at
        end
      end

      # Deleted files are handled by a separate cleanup job; the scan
      # itself only adds and updates.
      {add: to_add, update: to_update}
    end

    # Pipeline parse and DB write so the main thread can start upserting
    # the first book while later books are still being parsed. Workers
    # on a FixedThreadPool open / parse / cover-extract each file and
    # push the result onto a queue; the caller (this main thread)
    # consumes the queue and applies each result through the same
    # per-book transaction that apply_results used to drive. Total wall
    # time approaches max(parse_time, write_time) instead of their sum.
    #
    # Returns the ids of books that were created or updated so the
    # caller can dispatch the FTS sync in bulk.
    # Flush in-flight progress to the cache every N books so the UI
    # endpoint has fresh data without hammering Solid Cache (which is
    # an SQLite write of its own under the hood).
    PROGRESS_FLUSH_EVERY = 10
    PROGRESS_CACHE_TTL = 1.hour

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

    # Public so ScansController can read the same key.
    def self.progress_cache_key(scan_log_id)
      "scan_progress:#{scan_log_id}"
    end

    def progress_cache_key(scan_log_id)
      self.class.progress_cache_key(scan_log_id)
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
