# frozen_string_literal: true

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

  # Digit runs compare numerically so "2.jpg" precedes "10.jpg"; ties fall back
  # to the raw name to keep the order deterministic.
  def self.natural_sort(names)
    names.sort_by { |name| [natural_key(name), name] }
  end

  def self.natural_key(name)
    name.downcase.scan(/\d+|\D+/).map { |chunk| chunk.match?(/\A\d/) ? [0, chunk.to_i] : [1, chunk] }
  end

  COVER_NAME = /(?<![a-z])cover(?![a-z])|表紙/
  BACK_COVER_NAME = /(?<![a-z])(?:back|ura)(?![a-z])|裏/

  # Natural order, with the first file explicitly named as a front cover moved
  # to the front.
  def self.order_pages(names)
    sorted = natural_sort(names)
    cover = sorted.find { |name| cover_name?(name) }
    cover ? [cover, *(sorted - [cover])] : sorted
  end

  def self.cover_name?(name)
    base = File.basename(name, ".*").downcase
    base.match?(COVER_NAME) && !base.match?(BACK_COVER_NAME)
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
