# frozen_string_literal: true

require "rails_helper"

RSpec.describe Covers::Extractor do
  let(:library) { create(:library, path: Rails.root.join("spec/fixtures/files").to_s) }

  describe ".attach" do
    it "attaches JPEG bytes to a book" do
      book = create(:book, library: library)
      bytes = File.binread(Rails.root.join("spec/fixtures/files/sample_image_dir/001.jpg"))

      described_class.attach(book, bytes)

      expect(book.cover).to be_attached
      expect(book.cover.content_type).to eq("image/jpeg")
      expect(book.cover.byte_size).to eq(bytes.bytesize)
    end

    it "detects PNG by signature" do
      book = create(:book, library: library)
      png_bytes = File.binread(Rails.root.join("spec/fixtures/files/sample_image_dir/peppercredit.png"))

      described_class.attach(book, png_bytes)

      expect(book.cover.content_type).to eq("image/png")
      expect(book.cover.filename.to_s).to end_with(".png")
    end

    it "no-ops on nil bytes" do
      book = create(:book, library: library)
      expect { described_class.attach(book, nil) }.not_to change { book.cover.attached? }
      expect(book.cover).not_to be_attached
    end

    it "no-ops on empty bytes" do
      book = create(:book, library: library)
      described_class.attach(book, "")
      expect(book.cover).not_to be_attached
    end
  end

  describe ".call" do
    {
      cbz: "sample.cbz",
      epub: "sample.epub",
      pdf: "sample.pdf",
      image_dir: "sample_image_dir"
    }.each do |format, filename|
      context "with a #{format} fixture" do
        let(:book) { create(:book, library: library, file_path: filename, file_format: format) }

        it "attaches a cover" do
          described_class.call(book)
          expect(book.cover).to be_attached
          expect(book.cover.byte_size).to be > 0
        end
      end
    end

    it "warns and skips for a corrupted file" do
      tmp = Dir.mktmpdir("bookwall-cover-broken-")
      broken_library = create(:library, path: tmp)
      File.write(File.join(tmp, "broken.pdf"), "not a pdf")
      book = create(:book, library: broken_library, file_path: "broken.pdf", file_format: :pdf)

      expect(Rails.logger).to receive(:warn).with(/no cover/)
      described_class.call(book)
      expect(book.cover).not_to be_attached
    ensure
      FileUtils.remove_entry(tmp) if tmp && File.directory?(tmp)
    end
  end
end
