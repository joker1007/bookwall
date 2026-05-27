# frozen_string_literal: true

module Opds
  class DownloadsController < BaseController
    EXTENSIONS = {
      "cbz" => ".cbz",
      "epub" => ".epub",
      "pdf" => ".pdf",
      # image_dir is repackaged into a CBZ at download time, so the
      # client-visible extension is .cbz too.
      "image_dir" => ".cbz"
    }.freeze

    def file
      book = Book.find(params[:book_id])
      head :not_found and return unless params[:format].to_s == expected_format(book)

      resolved = File.expand_path(book.file_path)
      library_root = File.expand_path(book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        head :forbidden
        return
      end

      if book.file_format == "image_dir"
        send_data Opds::CbzBuilder.build(resolved),
          type: "application/x-cbz",
          disposition: "attachment",
          filename: download_filename(book)
      else
        send_file resolved,
          type: Opds::FeedBuilder.download_mime(book),
          disposition: "attachment",
          filename: download_filename(book)
      end
    end

    private

    def expected_format(book)
      case book.file_format.to_s
      when "image_dir" then "cbz"
      else book.file_format.to_s
      end
    end

    def download_filename(book)
      ext = EXTENSIONS.fetch(book.file_format.to_s, "")
      raw = book.title.to_s.strip.presence || "book-#{book.id}"
      # Strip path separators, control chars, and quotes so the title can't
      # break out of the Content-Disposition filename header.
      base = raw.gsub(/[\x00-\x1f\x7f"\/\\]/, "_")
      "#{base}#{ext}"
    end
  end
end
