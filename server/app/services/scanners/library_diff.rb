# frozen_string_literal: true

module Scanners
  # Partitions discovered jobs into {add:, update:}; deletions are intentionally not reported.
  class LibraryDiff
    def initialize(library)
      @library = library
    end

    def call(jobs)
      # DB stores paths library-relative; re-absolutise to match discovery's absolute paths.
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
          mtime = job[:mtime] || image_dir_mtime(job[:path])
          to_update << job if mtime > scanned_at
        end
      end

      {add: to_add, update: to_update}
    end

    private

    # The directory's own mtime moves when images are added or removed, which
    # child mtimes miss for removals and for copies that preserve timestamps.
    def image_dir_mtime(dir)
      best = File.mtime(dir)
      Dir.each_child(dir) do |name|
        m = File.mtime(File.join(dir, name))
      rescue Errno::ENOENT, SystemCallError
        next
      else
        best = m if m > best
      end
      best
    end
  end
end
