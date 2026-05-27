# frozen_string_literal: true

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

    # ETag for a single page. Same book + same file_hash + same page index
    # ⇒ same bytes, so we can cache aggressively in the browser. file_hash
    # changes whenever the scanner re-ingests the file (different content
    # ⇒ different hash), which invalidates the ETag automatically. Falls
    # back to updated_at when file_hash hasn't been computed yet
    # (e.g. image_dir books, where no archive hash is recorded).
    def self.etag_for(book, page_num)
      version = book.file_hash.presence || book.updated_at.to_i
      "#{version}-#{page_num}"
    end
  end
end
