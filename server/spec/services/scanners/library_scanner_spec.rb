require "rails_helper"

RSpec.describe Scanners::LibraryScanner do
  let(:tmpdir) { Dir.mktmpdir("bookwall-scanner-") }
  let(:library) { create(:library, path: tmpdir) }

  before do
    src = Rails.root.join("spec/fixtures/files")
    FileUtils.cp(src.join("sample.cbz"), tmpdir)
    FileUtils.cp(src.join("sample.epub"), tmpdir)
    FileUtils.cp(src.join("sample.pdf"), tmpdir)
    FileUtils.cp_r(src.join("sample_image_dir"), tmpdir)
  end

  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  describe "#call" do
    it "discovers and imports all supported formats" do
      log = described_class.new(library, pool_size: 2).call

      expect(library.books.count).to eq(4)
      formats = library.books.pluck(:file_format).sort
      expect(formats).to eq(%w[cbz epub image_dir pdf].sort)

      expect(log.status).to eq("succeeded")
      expect(log.found_count).to eq(4)
      expect(log.added_count).to eq(4)
      expect(log.removed_count).to eq(0)
    end

    it "computes file_hash for non-directory formats" do
      described_class.new(library).call

      file_book = library.books.where.not(file_format: "image_dir").first
      expect(file_book.file_hash).to match(/\A[0-9a-f]{64}\z/)
    end

    it "skips file_hash for image_dir" do
      described_class.new(library).call
      dir_book = library.books.find_by(file_format: "image_dir")
      expect(dir_book.file_hash).to be_nil
    end

    it "is idempotent on a second run with unchanged files" do
      described_class.new(library).call
      first_total = library.books.count

      log = described_class.new(library).call

      expect(library.books.count).to eq(first_total)
      expect(log.added_count).to eq(0)
      expect(log.updated_count).to eq(0)
    end

    it "removes books whose files were deleted" do
      described_class.new(library).call
      FileUtils.rm(File.join(tmpdir, "sample.epub"))

      log = described_class.new(library).call

      expect(library.books.where(file_path: File.join(tmpdir, "sample.epub"))).to be_empty
      expect(log.removed_count).to eq(1)
    end

    it "extracts authors and creates Author records" do
      described_class.new(library).call

      epub_book = library.books.find_by(file_format: "epub")
      expect(epub_book.authors.pluck(:name)).to include("Lewis Carroll")
    end

    it "updates last_scanned_at on the library" do
      expect { described_class.new(library).call }
        .to change { library.reload.last_scanned_at }
        .from(nil)
    end

    context "when a file is broken" do
      before do
        File.write(File.join(tmpdir, "broken.cbz"), "not a zip")
      end

      it "records a ScanLog but does not fail the whole run" do
        log = described_class.new(library).call
        expect(log.status).to eq("succeeded")
        expect(library.books.find_by(file_path: File.join(tmpdir, "broken.cbz"))).to be_nil
      end
    end
  end
end
