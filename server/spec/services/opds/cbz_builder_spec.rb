require "rails_helper"
require "zip"

RSpec.describe Opds::CbzBuilder do
  let(:dir_path) { Rails.root.join("spec/fixtures/files/sample_image_dir").to_s }

  describe ".build" do
    it "packs the image files into a CBZ with zero-padded sequential names" do
      bytes = described_class.build(dir_path)

      Zip::File.open_buffer(bytes) do |zip|
        entries = zip.entries.sort_by(&:name).map(&:name)
        expect(entries).to eq(%w[0001.jpg 0002.jpg 0003.jpg 0004.png])
      end
    end

    it "preserves the original image bytes" do
      bytes = described_class.build(dir_path)

      Zip::File.open_buffer(bytes) do |zip|
        first = zip.entries.find { |e| e.name == "0001.jpg" }
        expect(first.get_input_stream.read).to eq(File.binread(File.join(dir_path, "001.jpg")))
      end
    end

    it "skips non-image files" do
      Dir.mktmpdir("cbz-builder-") do |tmp|
        FileUtils.cp(File.join(dir_path, "001.jpg"), File.join(tmp, "a.jpg"))
        File.write(File.join(tmp, "notes.txt"), "ignore me")

        bytes = described_class.build(tmp)
        Zip::File.open_buffer(bytes) do |zip|
          expect(zip.entries.map(&:name)).to eq(%w[0001.jpg])
        end
      end
    end
  end
end
