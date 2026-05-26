require "rails_helper"

RSpec.describe Parsers::ImageDirParser do
  let(:path) { Rails.root.join("spec/fixtures/files/sample_image_dir").to_s }
  subject(:parser) { described_class.new(path) }

  describe "#metadata" do
    it "uses directory name as title" do
      expect(parser.metadata[:title]).to eq("sample_image_dir")
    end

    it "counts only image files" do
      expect(parser.page_count).to be > 0
    end
  end

  describe "#cover_bytes" do
    it "returns bytes of the first image (lexicographically)" do
      bytes = parser.cover_bytes
      expect(bytes).to be_a(String)
      expect(bytes.bytesize).to be > 0
    end
  end

  describe "#page_bytes" do
    it "returns the same bytes as cover for index 0" do
      expect(parser.page_bytes(0)).to eq(parser.cover_bytes)
    end

    it "raises for an out-of-range index" do
      expect { parser.page_bytes(9999) }.to raise_error(Parsers::Error)
    end
  end

  context "with an empty directory" do
    let(:path) { Dir.mktmpdir("bookwall-empty-imgdir-") }

    it "returns zero page_count" do
      expect(parser.page_count).to eq(0)
    end

    it "raises CoverNotFound" do
      expect { parser.cover_bytes }.to raise_error(Parsers::CoverNotFound)
    end
  end

  context "with non-image files mixed in" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-mixed-imgdir-")
      File.write(File.join(tmp, "001.jpg"), "fake-jpg")
      File.write(File.join(tmp, "002.png"), "fake-png")
      File.write(File.join(tmp, "notes.txt"), "ignored")
      tmp
    end

    it "ignores non-image files" do
      expect(parser.page_count).to eq(2)
    end
  end
end
