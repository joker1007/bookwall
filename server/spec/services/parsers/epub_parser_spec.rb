require "rails_helper"

RSpec.describe Parsers::EpubParser do
  let(:path) { Rails.root.join("spec/fixtures/files/sample.epub").to_s }
  subject(:parser) { described_class.new(path) }

  describe "#metadata" do
    it "extracts title and creators from OPF" do
      meta = parser.metadata
      expect(meta[:title]).to eq("Alice's Adventures in Wonderland")
      expect(meta[:authors]).to include("Lewis Carroll")
    end

    it "exposes page_count equal to spine size" do
      expect(parser.metadata[:page_count]).to eq(parser.page_count)
      expect(parser.page_count).to be > 0
    end
  end

  describe "#page_bytes" do
    it "returns xhtml/html content for spine index 0" do
      bytes = parser.page_bytes(0)
      expect(bytes).to be_a(String)
      expect(bytes.bytesize).to be > 0
    end
  end

  context "with the vertical Japanese EPUB" do
    let(:path) { Rails.root.join("spec/fixtures/files/sample_vertical_jp.epub").to_s }

    it "reads Japanese title and author" do
      meta = parser.metadata
      expect(meta[:title]).to eq("蜘蛛の糸")
      expect(meta[:authors]).to include("芥川龍之介")
    end

    it "exposes language and page-progression-direction" do
      expect(parser.language).to eq("ja")
      expect(parser.page_progression_direction).to eq("rtl")
    end
  end

  context "with a corrupted file" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-epub-broken-")
      file = File.join(tmp, "broken.epub")
      File.write(file, "not an epub")
      file
    end

    it "raises Parsers::InvalidFile" do
      expect { described_class.new(path).metadata }.to raise_error(Parsers::InvalidFile)
    end
  end
end
