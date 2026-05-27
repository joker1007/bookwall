# frozen_string_literal: true

module Opds
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
      page_num = params[:n].to_i
      # OPDS-PSE numbers pages from 0; negative input is malformed.
      raise ActionController::BadRequest, "page must be >= 0" if page_num.negative?

      etag = Books::PageStreaming.etag_for(book, page_num)
      response.set_header("Cache-Control", "private, max-age=31536000, immutable")
      return unless stale?(etag: etag)

      result = Books::PageStreaming.fetch(book, page_num)
      case result.status
      when :ok
        send_data result.bytes, type: result.content_type, disposition: "inline"
      when :not_found
        head :not_found
      end
    end
  end
end
