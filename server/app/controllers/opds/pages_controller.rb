module Opds
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
      # OPDS-PSE numbers pages from 0 to N-1 (spec v1.0+, anansi-project/opds-pse).
      # iOS clients such as Chunky and Panels request pageNumber=0 for the first
      # page; treating the value as 1-indexed shifted every page by one and made
      # the final page unreachable.
      page_num = params[:n].to_i
      raise ActionController::BadRequest, "page must be >= 0" if page_num.negative?

      parser = Parsers.for(book.file_path)
      bytes = parser.page_bytes(page_num)
      send_data bytes, type: parser.page_content_type(page_num), disposition: "inline"
    rescue Parsers::Error
      head :not_found
    end
  end
end
