# frozen_string_literal: true

module Scanners
  # Walks a library root and returns the set of book "jobs" to ingest. Each
  # job is a frozen hash {path:, format:, mtime:}. Uses two C-level globs:
  #   1. Find every image file and treat its parent directory as an image_dir
  #      book.
  #   2. Find every CBZ / EPUB / PDF. Files inside an already-identified
  #      image_dir are skipped so "image_dir wins, prune everything below it"
  #      semantics hold.
  # `File::FNM_CASEFOLD` matches `.JPG` / `.EPUB` etc. so users don't have to
  # normalise their library by hand.
  class LibraryDiscovery
    BOOK_FORMAT_GLOBS = {
      cbz: "**/*.cbz",
      epub: "**/*.epub",
      pdf: "**/*.pdf"
    }.freeze
    IMAGE_FORMAT_GLOBS = Parsers::IMAGE_EXTENSIONS.map { |ext| "**/*#{ext}" }.freeze

    def initialize(root)
      @root = File.expand_path(root)
    end

    def call
      image_dirs = collect_image_dirs
      jobs = image_dirs.map do |dir|
        # mtime is left nil and resolved lazily in LibraryDiff only when an
        # existing row needs to be compared — first-scan image dirs avoid the
        # per-child stat.
        {path: dir.freeze, format: :image_dir, mtime: nil}.freeze
      end

      BOOK_FORMAT_GLOBS.each do |fmt, pattern|
        Dir.glob(pattern, File::FNM_CASEFOLD, base: @root) do |rel|
          next if hidden_path?(rel)
          full = File.join(@root, rel)
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

    private

    def collect_image_dirs
      dirs = Set.new
      IMAGE_FORMAT_GLOBS.each do |pattern|
        Dir.glob(pattern, File::FNM_CASEFOLD, base: @root) do |rel|
          next if hidden_path?(rel)
          parent_rel = File.dirname(rel)
          # Library root itself is never a book, even if loose images got
          # dropped there.
          next if parent_rel == "."
          dirs << File.join(@root, parent_rel)
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
  end
end
