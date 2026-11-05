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

  # ZIP entries without the UTF-8 flag come back as BINARY; Japanese archives
  # made on Windows are usually Shift_JIS (CP932).
  def self.decode_entry_name(raw)
    utf8 = raw.dup.force_encoding(Encoding::UTF_8)
    return utf8 if utf8.valid_encoding?

    cp932 = restore_cp932_backslashes(raw).force_encoding(Encoding::Windows_31J)
    return cp932.encode(Encoding::UTF_8, undef: :replace) if cp932.valid_encoding?

    utf8.scrub
  end

  CP932_DOUBLE_BYTE = /[\x81-\x9F\xE0-\xFC][\x00-\xFF]/n

  # rubyzip rewrites every "\" to "/", which breaks CP932 characters whose
  # trail byte is 0x5C (表, ソ, 能...). "/" is never a valid trail byte, so
  # one following a lead byte must have been 0x5C.
  def self.restore_cp932_backslashes(raw)
    raw.b.gsub(CP932_DOUBLE_BYTE) { |pair| pair.end_with?("/") ? "#{pair[0]}\\".b : pair }
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
