# frozen_string_literal: true

module Scanners
  # Compares the discovered jobs against the library's existing book rows and
  # partitions them into {add:, update:}. Deleted files are intentionally not
  # reported — pruning is handled by a separate cleanup job so the scan's
  # writer-lock window stays short.
  class LibraryDiff
    def initialize(library)
      @library = library
    end

    def call(jobs)
      # Files on disk are seen as absolute paths during discovery, but the DB
      # holds them library-relative. Re-absolutise the DB rows for the
      # comparison so existing-record lookup still works.
      root = File.expand_path(@library.path)
      existing = @library.books.pluck(:file_path, :scanned_at).to_h do |rel, scanned_at|
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

      {add: to_add, update: to_update}
    end

    private

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
  end
end
