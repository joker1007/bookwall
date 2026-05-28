# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeriesSerializer do
  let(:library) { create(:library) }
  let(:series) { create(:series, library: library) }

  def serialize(record, params: {})
    described_class.new(record, params: params).serializable_hash
  end

  describe "book_count" do
    it "uses the preloaded count from params when present" do
      expect(serialize(series, params: {book_counts: {series.id => 3}})["book_count"]).to eq(3)
    end

    it "falls back to the association size when no counts are given" do
      create(:book, library: library, series: series, file_path: "s.cbz")
      expect(serialize(series)["book_count"]).to eq(1)
    end
  end

  describe "sample_cover_thumb_url" do
    it "uses the preloaded first book's cover when present" do
      book = attach_cover(create(:book, library: library, series: series, file_path: "s.cbz"))
      hash = serialize(series, params: {first_books: {series.id => book}})
      expect(hash["sample_cover_thumb_url"]).to be_present
    end

    it "falls back to the series' own first book when params are absent" do
      attach_cover(create(:book, library: library, series: series, file_path: "s.cbz"))
      expect(serialize(series)["sample_cover_thumb_url"]).to be_present
    end

    it "is nil when the series has no books with covers" do
      create(:book, library: library, series: series, file_path: "s.cbz")
      expect(serialize(series)["sample_cover_thumb_url"]).to be_nil
    end
  end
end
