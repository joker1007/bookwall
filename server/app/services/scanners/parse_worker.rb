# frozen_string_literal: true

# Pure-ruby worker invoked from a Concurrent::FixedThreadPool by
# Scanners::LibraryScanner. The worker MUST NOT touch ActiveRecord — the
# connection is not thread-safe to share, and writes are routed back to
# the main thread which serializes them through SQLite's single writer.
module Scanners
  module ParseWorker
    module_function

    def parse(job)
      path = job[:path]
      format = job[:format]
      parser = Parsers.for(path)
      meta = parser.metadata
      cover = cover_bytes_for(parser)

      {
        path: path,
        format: format.to_s,
        metadata: meta,
        file_size: size_for(path, format),
        mtime: mtime_for(path).to_i,
        cover_bytes: cover,
        error: nil
      }
    rescue StandardError => e
      {path: path, format: format&.to_s, error: e.message}
    end

    def cover_bytes_for(parser)
      parser.cover_bytes
    rescue Parsers::CoverNotFound, Parsers::InvalidFile
      nil
    end

    def size_for(path, format)
      return dir_size(path) if format == :image_dir
      File.size(path)
    end

    def dir_size(path)
      Dir.children(path).sum do |f|
        full = File.join(path, f)
        File.file?(full) ? File.size(full) : 0
      end
    end

    def mtime_for(path)
      if File.directory?(path)
        times = Dir.children(path).map { |f| File.mtime(File.join(path, f)) }
        times.max || Time.at(0)
      else
        File.mtime(path)
      end
    end
  end
end
