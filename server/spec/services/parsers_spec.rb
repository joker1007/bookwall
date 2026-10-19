# frozen_string_literal: true

require "rails_helper"

RSpec.describe Parsers do
  FIXTURES = Rails.root.join("spec/fixtures/files")

  describe ".format_for" do
    it "detects cbz by extension" do
      expect(described_class.format_for(FIXTURES.join("sample.cbz").to_s)).to eq(:cbz)
    end

    it "detects epub by extension" do
      expect(described_class.format_for(FIXTURES.join("sample.epub").to_s)).to eq(:epub)
    end

    it "detects pdf by extension" do
      expect(described_class.format_for(FIXTURES.join("sample.pdf").to_s)).to eq(:pdf)
    end

    it "detects image_dir for directories" do
      expect(described_class.format_for(FIXTURES.join("sample_image_dir").to_s)).to eq(:image_dir)
    end

    it "raises for unknown extensions" do
      expect {
        described_class.format_for(FIXTURES.join("unknown.txt").to_s)
      }.to raise_error(Parsers::UnsupportedFormat)
    end
  end

  describe ".natural_sort" do
    # Same vector as the Android NaturalOrderTest.
    it "sorts digit runs numerically and case-insensitively" do
      names = %w[Page10.jpg page2.jpg page1.jpg page01.jpg Page1.jpg ch10/001.jpg ch2/010.jpg ch2/2.jpg cover.jpg a.jpg]

      expect(described_class.natural_sort(names)).to eq(
        %w[a.jpg ch2/2.jpg ch2/010.jpg ch10/001.jpg cover.jpg Page1.jpg page01.jpg page1.jpg page2.jpg Page10.jpg]
      )
    end
  end

  describe ".for" do
    it "returns CbzParser for .cbz" do
      expect(described_class.for(FIXTURES.join("sample.cbz").to_s)).to be_a(Parsers::CbzParser)
    end

    it "returns EpubParser for .epub" do
      expect(described_class.for(FIXTURES.join("sample.epub").to_s)).to be_a(Parsers::EpubParser)
    end

    it "returns PdfParser for .pdf" do
      expect(described_class.for(FIXTURES.join("sample.pdf").to_s)).to be_a(Parsers::PdfParser)
    end

    it "returns ImageDirParser for a directory" do
      expect(described_class.for(FIXTURES.join("sample_image_dir").to_s)).to be_a(Parsers::ImageDirParser)
    end
  end
end
