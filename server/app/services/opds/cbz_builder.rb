# frozen_string_literal: true

require "zip"

module Opds
  # Packs an image_dir book into an in-memory CBZ archive so OPDS clients
  # that only know how to handle single-file downloads (CBZ / EPUB / PDF)
  # can still acquire image-directory books. The archive is built entirely
  # in memory and discarded once the HTTP response is sent.
  module CbzBuilder
    module_function

    # @param dir_path [String] absolute path to the book's image directory
    # @return [String] binary CBZ bytes ready to hand to send_data
    def build(dir_path)
      buffer = Zip::OutputStream.write_buffer do |zip|
        image_files(dir_path).each_with_index do |src_path, index|
          zip.put_next_entry(entry_name(src_path, index))
          File.open(src_path, "rb") { |f| IO.copy_stream(f, zip) }
        end
      end
      buffer.rewind
      buffer.read
    end

    def image_files(dir_path)
      Dir.children(dir_path)
        .select { |name| Parsers::IMAGE_EXTENSIONS.include?(File.extname(name).downcase) }
        .sort
        .map { |name| File.join(dir_path, name) }
    end

    # Entries are renamed to a zero-padded sequence so the natural
    # alphabetical sort that comic readers use yields the intended page
    # order even if the source filenames are inconsistent.
    def entry_name(src_path, index)
      format("%04d%s", index + 1, File.extname(src_path))
    end
  end
end
