module Books
  # Shared logic for streaming one image page from a Book to an HTTP client.
  # Used by both the OPDS-PSE page endpoint and the internal Web Reader API
  # so the parser dispatch and error mapping live in one place.
  module PageStreaming
    # Outcome value object. `status` is one of :ok, :bad_request, :not_found.
    # When :ok, `bytes` and `content_type` are populated.
    Result = Struct.new(:bytes, :content_type, :status, keyword_init: true) do
      def ok?
        status == :ok
      end
    end

    # OPDS-PSE numbers pages from 0. Negative indices are bad input; out-of-
    # range or corrupt files surface as Parsers::Error and map to 404.
    def self.fetch(book, page_num)
      return Result.new(status: :bad_request) if page_num.negative?

      parser = Parsers.for(book.file_path)
      Result.new(
        bytes: parser.page_bytes(page_num),
        content_type: parser.page_content_type(page_num),
        status: :ok
      )
    rescue Parsers::Error
      Result.new(status: :not_found)
    end
  end
end
