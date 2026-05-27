# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::FtsSyncJob, type: :job do
  describe "#perform" do
    it "upserts the FTS index for each id in the batch" do
      a = create(:book, title: "Alpha")
      b = create(:book, title: "Beta")

      expect(Books::FtsIndex).to receive(:upsert).with(book_with_id(a.id))
      expect(Books::FtsIndex).to receive(:upsert).with(book_with_id(b.id))
      described_class.perform_now([a.id, b.id], "upsert")
    end

    it "deletes the FTS rows for each id in the batch" do
      expect(Books::FtsIndex).to receive(:delete).with(10)
      expect(Books::FtsIndex).to receive(:delete).with(20)
      described_class.perform_now([10, 20], "delete")
    end

    it "no-ops on an empty id list" do
      expect(Books::FtsIndex).not_to receive(:upsert)
      expect(Books::FtsIndex).not_to receive(:delete)
      described_class.perform_now([], "upsert")
      described_class.perform_now([], "delete")
    end

    it "deduplicates ids in the batch" do
      book = create(:book)
      expect(Books::FtsIndex).to receive(:upsert).once.with(book_with_id(book.id))
      described_class.perform_now([book.id, book.id, book.id], "upsert")
    end

    it "raises on unknown ops" do
      expect {
        described_class.perform_now([1], "rebuild_everything")
      }.to raise_error(ArgumentError, /unknown FTS op/)
    end
  end

  def book_with_id(id)
    satisfy { |b| b.is_a?(Book) && b.id == id }
  end
end
