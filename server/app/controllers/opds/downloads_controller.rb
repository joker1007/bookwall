# frozen_string_literal: true

module Opds
  class DownloadsController < BaseController
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
        send_data Opds::CbzBuilder.build(resolved),
          type: Books::FileFormat.mime(book.file_format),
          disposition: "attachment",
          filename: Books::FileFormat.download_filename(book)
      else
        send_file resolved,
          type: Books::FileFormat.mime(book.file_format),
          disposition: "attachment",
          filename: Books::FileFormat.download_filename(book)
      end
    end

    private

    def expected_format(book)
      case book.file_format.to_s
      when "image_dir" then "cbz"
      else book.file_format.to_s
      end
    end
  end
end
