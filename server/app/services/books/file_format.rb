# frozen_string_literal: true

module Books
  # Single source of truth for mapping a book's file_format to its download
  # extension, MIME type, and a safe Content-Disposition filename. image_dir
  # books are repackaged as CBZ at download time, so they share CBZ's
  # extension and MIME.
  module FileFormat
    EXTENSIONS = {
      "cbz" => ".cbz",
      "epub" => ".epub",
      "pdf" => ".pdf",
      "image_dir" => ".cbz"
    }.freeze

    MIMES = {
      "cbz" => "application/x-cbz",
      "epub" => "application/epub+zip",
      "pdf" => "application/pdf",
      "image_dir" => "application/x-cbz"
    }.freeze

    DEFAULT_MIME = "application/octet-stream"

    # Path separators, control chars, and quotes are stripped so the title
    # can't break out of the Content-Disposition filename header.
    UNSAFE_FILENAME_CHARS = /[\x00-\x1f\x7f"\/\\]/

    module_function

    def extension(format)
      EXTENSIONS.fetch(format.to_s, "")
    end

    def mime(format)
      MIMES.fetch(format.to_s, DEFAULT_MIME)
    end

    def download_filename(book)
      raw = book.title.to_s.strip.presence || "book-#{book.id}"
      base = raw.gsub(UNSAFE_FILENAME_CHARS, "_")
      "#{base}#{extension(book.file_format)}"
    end
  end
end
