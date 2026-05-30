# frozen_string_literal: true

module Parsers
  class BaseParser
    attr_reader :path

    def initialize(path)
      @path = path
    end

    # @return [Hash] title:, series:, volume:, authors:[], tags:[], published_at:, page_count:
    def metadata
      raise NotImplementedError
    end

    def page_count
      raise NotImplementedError
    end

    def cover_bytes
      raise NotImplementedError
    end

    # index is 0-based.
    def page_bytes(index)
      raise NotImplementedError
    end

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
