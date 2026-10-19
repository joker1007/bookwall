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

  context "with unpadded page numbers" do
    let(:path) do
      cbz_path = File.join(Dir.mktmpdir("bookwall-cbz-natural-"), "natural.cbz")
      Zip::File.open(cbz_path, create: true) do |zip|
        %w[Pages/10.jpg Pages/2.jpg pages/1.JPG].each do |name|
          zip.get_output_stream(name) { |io| io.write(name) }
        end
      end
      cbz_path
    end

    it "orders pages naturally and uses the first as the cover" do
      expect((0...3).map { |i| parser.page_bytes(i) }).to eq(%w[pages/1.JPG Pages/2.jpg Pages/10.jpg])
      expect(parser.cover_bytes).to eq("pages/1.JPG")
    end
  end

  context "with a FrontCover page in ComicInfo.xml" do
    let(:front_cover_image) { "1" }
    let(:path) do
      cbz_path = File.join(Dir.mktmpdir("bookwall-cbz-front-cover-"), "front_cover.cbz")
      Zip::File.open(cbz_path, create: true) do |zip|
        %w[1.jpg 2.jpg 3.jpg].each { |name| zip.get_output_stream(name) { |io| io.write(name) } }
        zip.get_output_stream("ComicInfo.xml") do |io|
          io.write(%(<ComicInfo><Pages><Page Image="#{front_cover_image}" Type="FrontCover"/></Pages></ComicInfo>))
        end
      end
      cbz_path
    end

    it "uses that page as the cover without reordering pages" do
      expect(parser.cover_bytes).to eq("2.jpg")
      expect(parser.page_bytes(0)).to eq("1.jpg")
    end

    context "when the index is out of range" do
      let(:front_cover_image) { "9" }

      it "falls back to the first page" do
        expect(parser.cover_bytes).to eq("1.jpg")
      end
    end
  end

  describe "zip open count" do
    it "opens the zip once across metadata + cover_bytes + page_count" do
      opens = 0
      original = Zip::File.method(:open)
      allow(Zip::File).to receive(:open) do |*args, **kwargs, &blk|
        # Only count opens against the book we're parsing; spec setup
        # for ComicInfo creates its own CBZ files.
        opens += 1 if args.first == path
        original.call(*args, **kwargs, &blk)
      end

      parser.metadata
      parser.cover_bytes
      parser.page_count

      expect(opens).to eq(1)
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
