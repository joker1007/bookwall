# frozen_string_literal: true

require "rails_helper"

RSpec.describe CollectionSerializer do
  let(:library) { create(:library) }
  let(:collection) { create(:collection) }

  def serialize(record, params: {})
    described_class.new(record, params: params).serializable_hash
  end

  describe "book_count" do
    it "uses the preloaded count from params when present" do
      expect(serialize(collection, params: {book_counts: {collection.id => 5}})["book_count"]).to eq(5)
    end

    it "falls back to the association size when no counts are given" do
      collection.books << create(:book, library: library, file_path: "a.cbz")
      expect(serialize(collection)["book_count"]).to eq(1)
    end
  end

  describe "sample_cover_thumb_url" do
    it "uses the preloaded first book's cover when present" do
      book = create(:book, library: library, file_path: "a.cbz")
      book.cover.attach(io: StringIO.new("fake-jpg-bytes"), filename: "c.jpg", content_type: "image/jpeg")
      hash = serialize(collection, params: {first_books: {collection.id => book}})
      expect(hash["sample_cover_thumb_url"]).to be_present
    end

    it "is nil when the collection has no books with covers" do
      collection.books << create(:book, library: library, file_path: "a.cbz")
      expect(serialize(collection)["sample_cover_thumb_url"]).to be_nil
    end
  end
end
