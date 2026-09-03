# frozen_string_literal: true

# Single-range HTTP Range support for book file downloads. Falcon's send_file
# ignores Range, so the requested slice is streamed from the file in chunks
# (never loaded whole into memory). Callers set the ETag first so If-Range can
# refuse a resume against a file that changed since the client started.
module ByteRangeServing
  extend ActiveSupport::Concern

  CHUNK_SIZE = 64 * 1024

  class FileRangeBody
    def initialize(path, range)
      @path = path
      @range = range
    end

    def each
      File.open(@path, "rb") do |file|
        file.seek(@range.begin)
        remaining = @range.size
        while remaining > 0
          chunk = file.read([CHUNK_SIZE, remaining].min) or break
          remaining -= chunk.bytesize
          yield chunk
        end
      end
    end
  end

  private

  # Returns false (caller does the full send_file) for no/multipart range
  # requests and for an If-Range that does not match the current ETag.
  def serve_byte_range(path, type:, filename:)
    range_header = request.get_header("HTTP_RANGE")
    return false if range_header.blank?

    if_range = request.get_header("HTTP_IF_RANGE")
    return false if if_range.present? && if_range != response.etag

    file_size = File.size(path)
    ranges = Rack::Utils.get_byte_ranges(range_header, file_size)
    return false if ranges.nil?

    if ranges.empty?
      response.set_header("Content-Range", "bytes */#{file_size}")
      head :range_not_satisfiable
      return true
    end

    return false if ranges.size != 1

    range = ranges.first
    response.set_header("Content-Range", "bytes #{range.begin}-#{range.end}/#{file_size}")
    response.set_header("Content-Length", range.size.to_s)
    response.set_header("Content-Disposition", ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename))
    response.content_type = type
    self.status = :partial_content
    self.response_body = FileRangeBody.new(path, range)
    true
  end
end
