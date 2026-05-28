# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::FileFormat do
  describe ".extension" do
    it "maps known formats and treats image_dir as cbz" do
      expect(described_class.extension("cbz")).to eq(".cbz")
      expect(described_class.extension("epub")).to eq(".epub")
      expect(described_class.extension("pdf")).to eq(".pdf")
      expect(described_class.extension("image_dir")).to eq(".cbz")
    end

    it "returns an empty string for unknown formats" do
      expect(described_class.extension("xyz")).to eq("")
    end
  end

  describe ".mime" do
    it "maps known formats and treats image_dir as cbz" do
      expect(described_class.mime("cbz")).to eq("application/x-cbz")
      expect(described_class.mime("epub")).to eq("application/epub+zip")
      expect(described_class.mime("pdf")).to eq("application/pdf")
      expect(described_class.mime("image_dir")).to eq("application/x-cbz")
    end

    it "falls back to octet-stream for unknown formats" do
      expect(described_class.mime("xyz")).to eq("application/octet-stream")
    end
  end

  describe ".download_filename" do
    it "appends the format extension to the title" do
      book = build(:book, title: "Great Book", file_format: :epub)
      expect(described_class.download_filename(book)).to eq("Great Book.epub")
    end

    it "sanitizes path separators, control chars, and quotes" do
      book = build(:book, title: %(a/b\\c"d), file_format: :cbz)
      expect(described_class.download_filename(book)).to eq("a_b_c_d.cbz")
    end

    it "falls back to a book id slug when the title is blank" do
      book = build(:book, title: "  ", file_format: :pdf)
      book.id = 42
      expect(described_class.download_filename(book)).to eq("book-42.pdf")
    end
  end
end
