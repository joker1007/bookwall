# frozen_string_literal: true

module Api
  class PagesController < BaseController
    def show
      book = find_accessible_book!(params[:book_id])
      page_num = params[:n].to_i
      return head :bad_request if page_num.negative?

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
