require "find"

module Scanners
  class LibraryScanner
    DEFAULT_POOL_SIZE = ENV.fetch("BOOKWALL_SCAN_POOL_SIZE", 4).to_i

    attr_reader :library

    def initialize(library, pool_size: DEFAULT_POOL_SIZE)
      @library = library
      @pool_size = pool_size
    end

    def call
      log = library.scan_logs.create!(status: :running, started_at: Time.current)
      jobs = discover(library.path).freeze
      diff = diff_against_db(jobs)

      remove_books(diff[:remove])
      results = parse_parallel(diff[:add] + diff[:update])
      apply_results(results)

      library.update!(last_scanned_at: Time.current)
      log.update!(
        status: :succeeded,
        finished_at: Time.current,
        found_count: jobs.size,
        added_count: diff[:add].size,
        updated_count: diff[:update].size,
        removed_count: diff[:remove].size
      )
      log
    rescue StandardError => e
      log&.update!(
        status: :failed,
        finished_at: Time.current,
        error_message: e.message
      )
      raise
    end

    private

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
      existing = library.books.pluck(:file_path, :scanned_at).to_h
      job_paths = jobs.map { |j| j[:path] }

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

      {add: to_add, update: to_update, remove: existing.keys - job_paths}
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

    def remove_books(paths)
      return if paths.empty?
      library.books.where(file_path: paths).destroy_all
    end

    def apply_results(results)
      results.each do |result|
        next if result[:error]
        upsert_book(result)
      end
    end

    def upsert_book(result)
      meta = result[:metadata]
      author_records = upsert_named(Author, meta[:authors])
      tag_records = upsert_named(Tag, meta[:tags])
      series_record = ensure_series(meta[:series])

      book = library.books.find_or_initialize_by(file_path: result[:path])
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
  end
end
