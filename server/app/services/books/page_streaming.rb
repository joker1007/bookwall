# frozen_string_literal: true

module Books
  module PageStreaming
    Result = Struct.new(:bytes, :content_type, :status, keyword_init: true) do
      def ok?
        status == :ok
      end
    end

    # OPDS-PSE numbers pages from 0; out-of-range/corrupt files raise Parsers::Error.
    def self.fetch(book, page_num)
      return Result.new(status: :bad_request) if page_num.negative?

      parser = Parsers.for(book.absolute_path)
      Result.new(
        bytes: parser.page_bytes(page_num),
        content_type: parser.page_content_type(page_num),
        status: :ok
      )
    rescue Parsers::Error
      Result.new(status: :not_found)
    end

    # Re-scan bumps updated_at, which invalidates these cached page ETags.
    def self.etag_for(book, page_num)
      "#{book.updated_at.to_i}-#{page_num}"
    end
  end
end
