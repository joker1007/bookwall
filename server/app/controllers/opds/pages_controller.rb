# frozen_string_literal: true

module Opds
  class PagesController < BaseController
    def show
      book = Book.find(params[:book_id])
      result = Books::PageStreaming.fetch(book, params[:n].to_i)

      case result.status
      when :ok
        send_data result.bytes, type: result.content_type, disposition: "inline"
      when :bad_request
        # OPDS-PSE numbers pages from 0; negative input is malformed.
        raise ActionController::BadRequest, "page must be >= 0"
      when :not_found
        head :not_found
      end
    end
  end
end
