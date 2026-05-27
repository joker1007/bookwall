# frozen_string_literal: true

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

    it "leaves orphaned books in place (cleanup runs as a separate job)" do
      described_class.new(library).call
      FileUtils.rm(File.join(tmpdir, "sample.epub"))

      log = described_class.new(library).call

      # The scan no longer prunes books whose files have disappeared — that
      # belongs to a dedicated cleanup job, keeping the scan's writer-lock
      # window short.
      expect(library.books.where(file_path: "sample.epub")).to exist
      expect(log.removed_count).to eq(0)
    end

    it "extracts authors and creates Author records" do
      described_class.new(library).call

      epub_book = library.books.find_by(file_format: "epub")
      expect(epub_book.authors.pluck(:name)).to include("Lewis Carroll")
    end

    it "attaches a cover image to every book" do
      described_class.new(library).call
      attached = library.books.all.map { |b| b.cover.attached? }
      expect(attached).to all(be true)
    end

    it "updates last_scanned_at on the library" do
      expect { described_class.new(library).call }
        .to change { library.reload.last_scanned_at }
        .from(nil)
    end

    context "FTS job dispatch" do
      include ActiveJob::TestHelper

      around do |example|
        original = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :test
        example.run
      ensure
        ActiveJob::Base.queue_adapter = original
      end

      it "enqueues a single bulk upsert job covering every touched book" do
        expect {
          described_class.new(library).call
        }.to have_enqueued_job(Books::FtsSyncJob).with(
          ->(ids) { ids.is_a?(Array) && ids.size == 4 && ids.all?(Integer) },
          "upsert",
        ).exactly(:once)
      end

      it "does not enqueue per-book jobs during the scan (callbacks are suppressed)" do
        # Per-book Book#after_commit would fire 4 jobs; the scanner should
        # consolidate them into one.
        described_class.new(library).call
        upsert_jobs = enqueued_jobs.select { |j| j[:job] == Books::FtsSyncJob && j[:args].last == "upsert" }
        expect(upsert_jobs.size).to eq(1)
      end

      it "does not enqueue any delete job (cleanup is handled separately)" do
        described_class.new(library).call
        FileUtils.rm(File.join(tmpdir, "sample.cbz"))
        clear_enqueued_jobs

        described_class.new(library).call

        delete_jobs = enqueued_jobs.select { |j| j[:job] == Books::FtsSyncJob && j[:args].last == "delete" }
        expect(delete_jobs).to be_empty
      end

      it "rolls back the per-book transaction if any step fails" do
        # Make the cover attach blow up for one specific book; that book
        # must not leave half-written rows behind.
        broken_relative = "sample.cbz"
        allow(Covers::Extractor).to receive(:attach).and_wrap_original do |original, book, bytes|
          raise "boom" if book.file_path == broken_relative
          original.call(book, bytes)
        end

        expect {
          described_class.new(library).call
        }.to raise_error("boom")

        # The broken book's row must not exist (transaction rolled back),
        # nor should its tag / author joins be left behind.
        expect(library.books.where(file_path: broken_relative)).to be_empty
      end

      it "resets the thread-local skip flag even when the scan fails" do
        Thread.current[:bookwall_skip_fts_callback] = nil
        allow_any_instance_of(described_class).to receive(:apply_results).and_raise("boom")

        begin
          described_class.new(library).call
        rescue
        end

        expect(Thread.current[:bookwall_skip_fts_callback]).to be_nil
      end
    end

    context "series fallback from directory layout" do
      it "uses the parent directory name as the series when the book has no series metadata" do
        nested_dir = File.join(tmpdir, "Wonderland Series")
        FileUtils.mkdir_p(nested_dir)
        FileUtils.cp(Rails.root.join("spec/fixtures/files/sample.epub"), nested_dir)

        described_class.new(library).call

        nested_book = library.books.find_by(file_path: "Wonderland Series/sample.epub")
        expect(nested_book.series&.name).to eq("Wonderland Series")
      end

      it "leaves books at the library root with no series" do
        described_class.new(library).call

        root_epub = library.books.find_by(file_path: "sample.epub")
        expect(root_epub.series).to be_nil
      end
    end

    context "when a file is broken" do
      before do
        File.write(File.join(tmpdir, "broken.cbz"), "not a zip")
      end

      it "records a ScanLog but does not fail the whole run" do
        log = described_class.new(library).call
        expect(log.status).to eq("succeeded")
        expect(library.books.find_by(file_path: "broken.cbz")).to be_nil
      end
    end
  end

  describe "#with_busy_retry" do
    let(:scanner) { described_class.new(library) }

    around do |example|
      # Skip real sleeps inside Retriable so the suite stays fast.
      Retriable.configure { |c| c.sleep_disabled = true }
      example.run
    ensure
      Retriable.configure { |c| c.sleep_disabled = false }
    end

    def busy_error(message = "SQLite3::BusyException: database is locked")
      ActiveRecord::StatementInvalid.new(message)
    end

    it "retries transient SQLite BUSY errors until the block succeeds" do
      attempts = 0
      result = scanner.send(:with_busy_retry) do
        attempts += 1
        raise busy_error if attempts < 3
        :ok
      end
      expect(attempts).to eq(3)
      expect(result).to eq(:ok)
    end

    it "re-raises after exhausting the retry budget" do
      attempts = 0
      expect {
        scanner.send(:with_busy_retry) do
          attempts += 1
          raise busy_error
        end
      }.to raise_error(ActiveRecord::StatementInvalid)
      # Retriable's tries: 5 → 5 total attempts (1 initial + 4 retries).
      expect(attempts).to eq(5)
    end

    it "passes through non-busy StatementInvalid errors immediately" do
      attempts = 0
      expect {
        scanner.send(:with_busy_retry) do
          attempts += 1
          raise ActiveRecord::StatementInvalid, "constraint violation"
        end
      }.to raise_error(ActiveRecord::StatementInvalid, /constraint violation/)
      expect(attempts).to eq(1)
    end
  end
end
