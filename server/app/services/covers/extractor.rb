# frozen_string_literal: true

module Covers
  module Extractor
    DETECT_RULES = {
      "\x89PNG".b => ["image/png", ".png"],
      "GIF8".b => ["image/gif", ".gif"],
      "RIFF".b => ["image/webp", ".webp"]
    }.freeze

    module_function

    def attach(book, bytes)
      return if bytes.nil? || bytes.empty?
      filename = "book-#{book.id || SecureRandom.hex(4)}-cover#{detect_extension(bytes)}"
      book.cover.attach(
        io: StringIO.new(bytes),
        filename: filename,
        content_type: detect_content_type(bytes)
      )
    rescue StandardError => e
      Rails.logger.warn("[Covers::Extractor] failed to attach for book #{book.id}: #{e.message}")
      nil
    end

    def call(book)
      parser = Parsers.for(book.absolute_path)
      attach(book, parser.cover_bytes)
    rescue Parsers::CoverNotFound, Parsers::InvalidFile => e
      Rails.logger.warn("[Covers::Extractor] no cover for book #{book.id}: #{e.message}")
      nil
    end

    def detect_content_type(bytes)
      DETECT_RULES[bytes[0, 4]&.b]&.first || "image/jpeg"
    end

    def detect_extension(bytes)
      DETECT_RULES[bytes[0, 4]&.b]&.last || ".jpg"
    end
  end
end
