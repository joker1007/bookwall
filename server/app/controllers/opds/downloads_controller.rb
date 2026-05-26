module Opds
  class DownloadsController < BaseController
    def file
      book = Book.find(params[:book_id])
      head :not_found and return if book.file_format == "image_dir"

      resolved = File.expand_path(book.file_path)
      library_root = File.expand_path(book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        head :forbidden
        return
      end

      send_file resolved, type: Opds::FeedBuilder.download_mime(book), disposition: "attachment"
    end
  end
end
