# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthorSerializer do
  let(:library) { create(:library) }
  let(:author) { create(:author) }

  def serialize(record, params: {})
    described_class.new(record, params: params).serializable_hash
  end

  describe "book_count" do
    it "uses the preloaded count from params when present" do
      hash = serialize(author, params: {book_counts: {author.id => 7}})
      expect(hash["book_count"]).to eq(7)
    end

    it "defaults to zero for an author missing from the preloaded counts" do
      hash = serialize(author, params: {book_counts: {}})
      expect(hash["book_count"]).to eq(0)
    end

    it "falls back to the association size when no counts are given" do
      book = create(:book, library: library, file_path: "a.cbz")
      book.authors << author
      expect(serialize(author)["book_count"]).to eq(1)
    end
  end

  describe "sample_cover_thumb_url" do
    it "uses the preloaded first book's cover when present" do
      book = attach_cover(create(:book, library: library, file_path: "a.cbz"))
      hash = serialize(author, params: {first_books: {author.id => book}})
      expect(hash["sample_cover_thumb_url"]).to be_present
    end

    it "is nil when the preloaded first book has no cover" do
      book = create(:book, library: library, file_path: "a.cbz")
      hash = serialize(author, params: {first_books: {author.id => book}})
      expect(hash["sample_cover_thumb_url"]).to be_nil
    end

    it "is nil when the author has no books at all" do
      expect(serialize(author)["sample_cover_thumb_url"]).to be_nil
    end
  end
end
