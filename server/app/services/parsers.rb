module Parsers
  class Error < StandardError; end
  class UnsupportedFormat < Error; end
  class CoverNotFound < Error; end
  class InvalidFile < Error; end

  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp .gif].freeze

  EXTENSION_MIME_TYPES = {
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".gif" => "image/gif"
  }.freeze

  def self.mime_type_for_extension(filename, default: "application/octet-stream")
    EXTENSION_MIME_TYPES.fetch(File.extname(filename).downcase, default)
  end

  module_function

  def for(path)
    case format_for(path)
    when :cbz then CbzParser.new(path)
    when :epub then EpubParser.new(path)
    when :pdf then PdfParser.new(path)
    when :image_dir then ImageDirParser.new(path)
    end
  end

  def format_for(path)
    return :image_dir if File.directory?(path)

    case File.extname(path).downcase
    when ".cbz" then :cbz
    when ".epub" then :epub
    when ".pdf" then :pdf
    else
      raise UnsupportedFormat, path
    end
  end
end
