# frozen_string_literal: true

module Books
  # image_dir books are repackaged as CBZ at download time, so they share CBZ's extension/MIME.
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

    # Stripped to prevent breaking out of the Content-Disposition filename header.
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
