# frozen_string_literal: true

module Scanners
  # Returns the set of book jobs {path:, format:, mtime:}; an image_dir wins over
  # any book file nested below it.
  class LibraryDiscovery
    # Dir.glob ignores File::FNM_CASEFOLD, so expand each letter into a `[lU]` class.
    def self.casefold_glob(ext)
      ext.chars.map { |c| /[a-z]/i.match?(c) ? "[#{c.downcase}#{c.upcase}]" : c }.join
    end

    BOOK_FORMAT_GLOBS = {
      cbz: "**/*#{casefold_glob(".cbz")}",
      epub: "**/*#{casefold_glob(".epub")}",
      pdf: "**/*#{casefold_glob(".pdf")}"
    }.freeze
    IMAGE_FORMAT_GLOBS = Parsers::IMAGE_EXTENSIONS.map { |ext| "**/*#{casefold_glob(ext)}" }.freeze

    def initialize(root)
      @root = File.expand_path(root)
    end

    def call
      image_dirs = collect_image_dirs
      jobs = image_dirs.map do |dir|
        # mtime left nil and resolved lazily in LibraryDiff to skip the per-child stat.
        {path: dir.freeze, format: :image_dir, mtime: nil}.freeze
      end

      BOOK_FORMAT_GLOBS.each do |fmt, pattern|
        Dir.glob(pattern, base: @root) do |rel|
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
        Dir.glob(pattern, base: @root) do |rel|
          next if hidden_path?(rel)
          parent_rel = File.dirname(rel)
          # Loose images at the library root never form a book.
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
