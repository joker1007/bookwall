# frozen_string_literal: true

require "rails_helper"

RSpec.describe Parsers::PdfParser do
  let(:path) { Rails.root.join("spec/fixtures/files/sample.pdf").to_s }
  subject(:parser) { described_class.new(path) }

  describe "#metadata" do
    it "returns a hash with required keys" do
      meta = parser.metadata
      expect(meta).to include(:title, :authors, :page_count, :published_at)
      expect(meta[:title]).to be_a(String).and be_present
    end

    it "reports page_count from hexapdf" do
      expect(parser.metadata[:page_count]).to be > 0
      expect(parser.page_count).to eq(parser.metadata[:page_count])
    end
  end

  describe "#cover_bytes" do
    it "returns JPEG bytes rasterized from the first page" do
      bytes = parser.cover_bytes
      expect(bytes).to be_a(String)
      expect(bytes.bytesize).to be > 1000
      expect(bytes[0, 3].bytes).to eq([0xFF, 0xD8, 0xFF])
    end
  end

  describe "#page_bytes" do
    it "returns the same bytes as cover for index 0" do
      cover = parser.cover_bytes
      first = parser.page_bytes(0)
      expect(first.bytesize).to eq(cover.bytesize)
    end
  end

  context "with a corrupted file" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-pdf-broken-")
      file = File.join(tmp, "broken.pdf")
      File.write(file, "not a pdf")
      file
    end

    it "raises Parsers::InvalidFile on metadata" do
      expect { described_class.new(path).metadata }.to raise_error(Parsers::InvalidFile)
    end
  end
end
