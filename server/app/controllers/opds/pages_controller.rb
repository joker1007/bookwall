module Opds
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
      page_num = params[:n].to_i
      raise ActionController::BadRequest, "page must be >= 1" if page_num < 1

      parser = Parsers.for(book.file_path)
      bytes = parser.page_bytes(page_num - 1)
      send_data bytes, type: "image/jpeg", disposition: "inline"
    rescue Parsers::Error => e
      head :not_found
    end
  end
end
