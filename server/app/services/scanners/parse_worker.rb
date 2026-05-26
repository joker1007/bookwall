require "digest"

# Pure-ruby worker invoked from a Concurrent::FixedThreadPool by
# Scanners::LibraryScanner. The worker MUST NOT touch ActiveRecord — the
# connection is not thread-safe to share, and writes are routed back to
# the main thread which serializes them through SQLite's single writer.
module Scanners
  module ParseWorker
    READ_CHUNK = 1024 * 1024

    module_function

    def parse(job)
      path = job[:path]
      format = job[:format]
      parser = Parsers.for(path)
      meta = parser.metadata

      {
        path: path,
        format: format.to_s,
        metadata: meta,
        file_hash: file_hash_for(path, format),
        file_size: size_for(path, format),
        mtime: mtime_for(path).to_i,
        error: nil
      }
    rescue StandardError => e
      {path: path, format: format&.to_s, error: e.message}
    end

    def file_hash_for(path, format)
      return nil if format == :image_dir
      digest = Digest::SHA256.new
      File.open(path, "rb") do |f|
        while (chunk = f.read(READ_CHUNK))
          digest.update(chunk)
        end
      end
      digest.hexdigest
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
