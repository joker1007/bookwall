module Parsers
  class BaseParser
    attr_reader :path

    def initialize(path)
      @path = path
    end

    # @return [Hash{Symbol=>Object}] title:, series:, volume:, authors:[],
    #   tags:[], published_at:, page_count:
    def metadata
      raise NotImplementedError
    end

    def page_count
      raise NotImplementedError
    end

    # @return [String] binary image bytes (JPEG/PNG/WebP)
    def cover_bytes
      raise NotImplementedError
    end

    # @param index [Integer] 0-based page index
    # @return [String] binary image bytes
    def page_bytes(index)
      raise NotImplementedError
    end

    # @param index [Integer] 0-based page index
    # @return [String] MIME type of the bytes returned by #page_bytes(index)
    def page_content_type(_index)
      "image/jpeg"
    end

    protected

    def basename_without_ext
      File.basename(@path, ".*")
    end

    def parent_dirname
      File.basename(File.dirname(@path))
    end
  end
end
