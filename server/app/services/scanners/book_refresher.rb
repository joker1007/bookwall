# frozen_string_literal: true

module Scanners
  # Re-reads a single book from its file on demand, bypassing the mtime check
  # that a library scan uses to skip unchanged files.
  class BookRefresher
    include SqliteRetryable

    class Error < StandardError; end

    attr_reader :book

    def initialize(book)
      @book = book
    end

    # Overwrites manual edits with whatever the file currently carries.
    def reload_metadata!
      ensure_file_exists!
      result = Scanners::ParseWorker.parse(path: book.absolute_path, format: book.file_format.to_sym)
      raise Error, result[:error] if result[:error]

      with_busy_retry do
        ActiveRecord::Base.transaction do
          Scanners::LibraryScanner.new(book.library).upsert_book(result, attach_cover: false)
        end
      end
      book.reload
    end

    def regenerate_cover!
      ensure_file_exists!
      bytes = Parsers.for(book.absolute_path).cover_bytes
      raise Error, "cover could not be attached" unless Covers::Extractor.attach(book, bytes)

      Scanners::ThumbnailPreprocessor.new.call([book.id])
      book.reload
    rescue Parsers::Error => e
      raise Error, e.message
    end

    private

    def ensure_file_exists!
      path = book.absolute_path
      root = File.expand_path(book.library.path)
      raise Error, "file is outside the library" unless path.start_with?("#{root}/")
      raise Error, "file not found" unless File.exist?(path)
    end
  end
end
