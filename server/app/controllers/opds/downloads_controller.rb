module Opds
  class DownloadsController < BaseController
    EXTENSIONS = {
      "cbz" => ".cbz",
      "epub" => ".epub",
      "pdf" => ".pdf"
    }.freeze

    def file
      book = Book.find(params[:book_id])
      head :not_found and return if book.file_format == "image_dir"
      head :not_found and return if params[:format].to_s != book.file_format.to_s

      resolved = File.expand_path(book.file_path)
      library_root = File.expand_path(book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        head :forbidden
        return
      end

      send_file resolved,
        type: Opds::FeedBuilder.download_mime(book),
        disposition: "attachment",
        filename: download_filename(book)
    end

    private

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
