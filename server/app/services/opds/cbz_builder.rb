# frozen_string_literal: true

module Opds
  module CbzBuilder
    module_function

    # Streams the directory's images into `zip` (a ZipKit::Streamer) as a CBZ.
    # Images are already compressed formats, so store them without deflating.
    def stream(dir_path, zip)
      image_files(dir_path).each_with_index do |src_path, index|
        zip.write_stored_file(entry_name(src_path, index)) do |sink|
          File.open(src_path, "rb") { |f| IO.copy_stream(f, sink) }
        end
      end
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
