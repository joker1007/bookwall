# frozen_string_literal: true

module Opds
  class DownloadsController < BaseController
    include ZipKit::RailsStreaming
    include ByteRangeServing

    def file
      book = find_accessible_book!(params[:book_id])
      head :not_found and return unless params[:format].to_s == expected_format(book)

      resolved = book.absolute_path
      library_root = File.expand_path(book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        head :forbidden
        return
      end

      if book.file_format == "image_dir"
        # image_dir has no single file, so repackage the directory's images into
        # a CBZ streamed straight to the response. Streaming keeps memory flat and
        # starts sending bytes immediately, even for multi-GB directories.
        zip_kit_stream(
          filename: Books::FileFormat.download_filename(book),
          type: Books::FileFormat.mime(book.file_format)
        ) { |zip| Opds::CbzBuilder.stream(resolved, zip) }
      else
        send_single_file(book, resolved)
      end
    end

    private

    def send_single_file(book, path)
      mime = Books::FileFormat.mime(book.file_format)
      filename = Books::FileFormat.download_filename(book)
      response.set_header("Accept-Ranges", "bytes")
      return unless stale?(strong_etag: book.updated_at.to_i.to_s)
      return if serve_byte_range(path, type: mime, filename: filename)

      send_file path, type: mime, disposition: "attachment", filename: filename
    end

    def expected_format(book)
      case book.file_format.to_s
      when "image_dir" then "cbz"
      else book.file_format.to_s
      end
    end
  end
end
