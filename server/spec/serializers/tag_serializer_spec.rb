# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagSerializer do
  let(:library) { create(:library) }
  let(:tag) { create(:tag) }

  def serialize(record, params: {})
    described_class.new(record, params: params).serializable_hash
  end

  describe "book_count" do
    it "uses the preloaded count from params when present" do
      expect(serialize(tag, params: {book_counts: {tag.id => 4}})["book_count"]).to eq(4)
    end

    it "defaults to zero for a tag missing from the preloaded counts" do
      expect(serialize(tag, params: {book_counts: {}})["book_count"]).to eq(0)
    end

    it "falls back to the association size when no counts are given" do
      book = create(:book, library: library, file_path: "t.cbz")
      book.tags << tag
      expect(serialize(tag)["book_count"]).to eq(1)
    end
  end
end
