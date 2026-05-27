module Api
  # In-app Web Reader page delivery. Uses the regular session-cookie auth
  # rather than the OPDS Bearer/Basic path so an <img src=...> element in the
  # SPA streams the image without extra headers.
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
      result = Books::PageStreaming.fetch(book, params[:n].to_i)

      case result.status
      when :ok
        send_data result.bytes, type: result.content_type, disposition: "inline"
      when :bad_request
        head :bad_request
      when :not_found
        head :not_found
      end
    end
  end
end
