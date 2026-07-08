# frozen_string_literal: true

require "rails_helper"
require "zip"

RSpec.describe Opds::CbzBuilder do
  let(:dir_path) { Rails.root.join("spec/fixtures/files/sample_image_dir").to_s }

  def stream_to_buffer(dir)
    io = StringIO.new
    ZipKit::Streamer.open(io) { |zip| described_class.stream(dir, zip) }
    io.rewind
    io
  end

  describe ".stream" do
    it "packs the image files into a CBZ with zero-padded sequential names" do
      Zip::File.open_buffer(stream_to_buffer(dir_path)) do |zip|
        entries = zip.entries.sort_by(&:name).map(&:name)
        expect(entries).to eq(%w[0001.jpg 0002.jpg 0003.jpg 0004.png])
      end
    end

    it "preserves the original image bytes" do
      Zip::File.open_buffer(stream_to_buffer(dir_path)) do |zip|
        first = zip.entries.find { |e| e.name == "0001.jpg" }
        expect(first.get_input_stream.read.b).to eq(File.binread(File.join(dir_path, "001.jpg")))
      end
    end

    it "stores entries without compression" do
      Zip::File.open_buffer(stream_to_buffer(dir_path)) do |zip|
        expect(zip.entries.map(&:compression_method)).to all(eq(Zip::Entry::STORED))
      end
    end

    it "skips non-image files" do
      Dir.mktmpdir("cbz-builder-") do |tmp|
        FileUtils.cp(File.join(dir_path, "001.jpg"), File.join(tmp, "a.jpg"))
        File.write(File.join(tmp, "notes.txt"), "ignore me")

        Zip::File.open_buffer(stream_to_buffer(tmp)) do |zip|
          expect(zip.entries.map(&:name)).to eq(%w[0001.jpg])
        end
      end
    end
  end
end
