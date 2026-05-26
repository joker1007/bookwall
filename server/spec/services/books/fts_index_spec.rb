require "rails_helper"

RSpec.describe Books::FtsIndex do
  let(:library) { create(:library) }
  let(:book) { create(:book, library: library, title: "Searchable Title") }

  describe ".upsert" do
    it "indexes the book title for FTS search" do
      described_class.upsert(book)
      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(["SELECT rowid FROM books_fts WHERE books_fts MATCH ?", "Searchable"])
      ).to_a
      expect(result.map { |r| r["rowid"] }).to include(book.id)
    end
  end

  describe ".delete" do
    it "removes the book from the FTS index" do
      described_class.upsert(book)
      described_class.delete(book.id)
      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(["SELECT rowid FROM books_fts WHERE books_fts MATCH ?", "Searchable"])
      ).to_a
      expect(result.map { |r| r["rowid"] }).not_to include(book.id)
    end
  end

  describe "automatic sync via Book callbacks" do
    it "indexes on create" do
      new_book = create(:book, library: library, title: "Auto Indexed Book")
      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(["SELECT rowid FROM books_fts WHERE books_fts MATCH ?", "Auto"])
      ).to_a
      expect(result.map { |r| r["rowid"] }).to include(new_book.id)
    end

    it "removes on destroy" do
      new_book = create(:book, library: library, title: "Soon Removed")
      id = new_book.id
      new_book.destroy!
      result = ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql_array(["SELECT rowid FROM books_fts WHERE books_fts MATCH ?", "Removed"])
      ).to_a
      expect(result.map { |r| r["rowid"] }).not_to include(id)
    end
  end
end
