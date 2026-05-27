# frozen_string_literal: true

require "rails_helper"

RSpec.describe Parsers::CbzParser do
  let(:path) { Rails.root.join("spec/fixtures/files/sample.cbz").to_s }
  subject(:parser) { described_class.new(path) }

  describe "#metadata" do
    it "falls back to filename when ComicInfo.xml is absent" do
      meta = parser.metadata
      expect(meta[:title]).to eq("sample")
      expect(meta[:authors]).to eq([])
      expect(meta[:tags]).to eq([])
      expect(meta[:volume]).to be_nil
    end

    it "reports the image page count" do
      expect(parser.metadata[:page_count]).to be > 0
    end
  end

  describe "#page_count" do
    it "counts only image entries" do
      expect(parser.page_count).to be > 0
    end
  end

  describe "#cover_bytes" do
    it "returns binary bytes of the first image" do
      bytes = parser.cover_bytes
      expect(bytes).to be_a(String)
      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
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

  context "with ComicInfo.xml embedded" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-cbz-test-")
      cbz_path = File.join(tmp, "with_info.cbz")
      Zip::File.open(cbz_path, create: true) do |zip|
        zip.get_output_stream("001.jpg") { |io| io.write("img1") }
        zip.get_output_stream("002.jpg") { |io| io.write("img2") }
        zip.get_output_stream("ComicInfo.xml") do |io|
          io.write(<<~XML)
            <?xml version="1.0"?>
            <ComicInfo>
              <Title>Test Title</Title>
              <Series>Test Series</Series>
              <Number>3</Number>
              <Writer>Alice, Bob</Writer>
              <Tags>action, comedy</Tags>
              <Year>2020</Year>
              <Month>5</Month>
              <Day>15</Day>
            </ComicInfo>
          XML
        end
      end
      cbz_path
    end

    it "parses ComicInfo metadata" do
      meta = described_class.new(path).metadata
      expect(meta[:title]).to eq("Test Title")
      expect(meta[:series]).to eq("Test Series")
      expect(meta[:volume]).to eq(3)
      expect(meta[:authors]).to eq(["Alice", "Bob"])
      expect(meta[:tags]).to eq(["action", "comedy"])
      expect(meta[:published_at]).to eq(Date.new(2020, 5, 15))
    end
  end

  context "with a corrupted file" do
    let(:path) do
      tmp = Dir.mktmpdir("bookwall-cbz-broken-")
      file = File.join(tmp, "broken.cbz")
      File.write(file, "not a zip")
      file
    end

    it "raises Parsers::InvalidFile" do
      expect { described_class.new(path).metadata }.to raise_error(Parsers::InvalidFile)
    end
  end
end
