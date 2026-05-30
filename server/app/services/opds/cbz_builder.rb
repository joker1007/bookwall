# frozen_string_literal: true

require "zip"

module Opds
  module CbzBuilder
    module_function

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

    # Zero-pad so comic readers' alphabetical page sort matches intended order.
    def entry_name(src_path, index)
      format("%04d%s", index + 1, File.extname(src_path))
    end
  end
end
