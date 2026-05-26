module Parsers
  class ImageDirParser < BaseParser
    def metadata
      {
        title: File.basename(@path),
        series: nil,
        volume: nil,
        authors: [],
        tags: [],
        published_at: nil,
        page_count: image_files.size
      }
    end

    def page_count
      image_files.size
    end

    def cover_bytes
      raise CoverNotFound, @path if image_files.empty?
      File.binread(image_files.first)
    end

    def page_bytes(index)
      File.binread(image_files.fetch(index))
    rescue IndexError
      raise Error, "page index out of range: #{index}"
    end

    private

    def image_files
      @image_files ||= Dir.children(@path)
        .select { |f| IMAGE_EXTENSIONS.include?(File.extname(f).downcase) }
        .sort
        .map { |f| File.join(@path, f) }
    end
  end
end
