# frozen_string_literal: true

module Api
  # In-app Web Reader page delivery. Uses the regular session-cookie auth
  # rather than the OPDS Bearer/Basic path so an <img src=...> element in the
  # SPA streams the image without extra headers.
  #
  # The bytes for a given (book, page) are immutable for as long as
  # book.file_hash is unchanged, so we let the browser cache them
  # aggressively. A matching If-None-Match returns 304 with no body, and
  # the long max-age means subsequent loads come from the disk cache
  # without even hitting the server.
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
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
