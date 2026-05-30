# frozen_string_literal: true

module Api
  class FilesystemController < BaseController
    DEFAULT_ROOT = "/"
    MAX_ENTRIES = 500

    def browse
      raw = params[:path].to_s.presence || ENV.fetch("BOOKWALL_BROWSE_ROOT", DEFAULT_ROOT)
      target = Pathname.new(File.expand_path(raw))

      render json: payload_for(target)
    end

    private

    def payload_for(target)
      unless target.exist?
        return {
          path: target.to_s,
          parent: target.parent.to_s,
          exists: false,
          readable: false,
          entries: []
        }
      end

      dir = target.directory? ? target : target.parent
      readable = dir.readable?

      {
        path: dir.to_s,
        parent: parent_of(dir),
        exists: true,
        readable: readable,
        entries: readable ? list_directories(dir) : []
      }
    end

    def parent_of(dir)
      parent = dir.parent
      # Pathname("/").parent == Pathname("/"); detect root by self-equality.
      return nil if parent.to_s == dir.to_s
      parent.to_s
    end

    def list_directories(dir)
      entries = []
      dir.each_child(false) do |basename|
        full = dir.join(basename)
        next unless full.directory?
        entries << {name: basename.to_s, path: full.to_s}
        break if entries.size >= MAX_ENTRIES
      end
      entries.sort_by { |e| e[:name].downcase }
    rescue Errno::EACCES, Errno::ENOENT
      []
    end
  end
end
