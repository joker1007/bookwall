# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookSerializer do
  let(:library) { create(:library) }
  let(:user) { create(:user) }

  def serialize(record, params: {})
    described_class.new(record, params: params).serializable_hash
  end

  describe "basic attributes" do
    it "exposes the series name, authors, and tags" do
      series = create(:series, library: library, name: "Saga")
      book = create(:book, library: library, series: series, title: "Vol 1")
      book.authors << create(:author, name: "Alice")
      book.tags << create(:tag, name: "fantasy")

      hash = serialize(book)
      expect(hash["title"]).to eq("Vol 1")
      expect(hash["series_name"]).to eq("Saga")
      expect(hash["authors"]).to contain_exactly(include(name: "Alice"))
      expect(hash["tags"]).to contain_exactly(include(name: "fantasy"))
    end
  end

  describe "favorited" do
    it "is true when the book id is in favorite_book_ids" do
      book = create(:book, library: library)
      expect(serialize(book, params: {favorite_book_ids: [book.id]})["favorited"]).to be(true)
    end

    it "is false otherwise" do
      book = create(:book, library: library)
      expect(serialize(book, params: {favorite_book_ids: []})["favorited"]).to be(false)
    end
  end

  describe "cover" do
    it "is nil when no cover is attached" do
      book = create(:book, library: library)
      expect(serialize(book)["cover"]).to be_nil
    end

    it "exposes url and thumb_url when attached" do
      book = attach_cover(create(:book, library: library))
      cover = serialize(book)["cover"]
      expect(cover[:url]).to be_present
      expect(cover[:thumb_url]).to be_present
    end
  end

  describe "reading_progress" do
    it "is nil when the user has no stored progress for the book" do
      book = create(:book, library: library, file_format: :cbz, page_count: 11)
      expect(serialize(book)["reading_progress"]).to be_nil
    end

    it "exposes the computed fraction and current page when present" do
      book = create(:book, library: library, file_format: :cbz, page_count: 11)
      progress = ReadingProgress.create!(user: user, book: book, current_page: 5,
        last_read_at: 1.hour.ago)

      hash = serialize(book, params: {reading_progress_by_book_id: {book.id => progress}})
      expect(hash["reading_progress"]).to include(
        fraction: 0.5,
        current_page: 5
      )
      expect(hash["reading_progress"][:last_read_at]).to be_present
    end
  end
end
