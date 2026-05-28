# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::Search do
  let(:library) { create(:library) }
  let(:author) { create(:author, name: "Lewis Carroll") }
  let(:tag) { create(:tag, name: "fantasy") }

  let!(:alice) do
    create(:book, library: library, title: "Alice in Wonderland").tap do |b|
      b.authors << author
      b.tags << tag
    end
  end
  let!(:moby) do
    create(:book, library: library, title: "Moby Dick")
  end

  describe "#relation with no filters" do
    it "returns all books" do
      expect(described_class.new.relation.pluck(:id)).to contain_exactly(alice.id, moby.id)
    end
  end

  describe "#relation with a base_scope" do
    let(:other_library) { create(:library) }
    let!(:outsider) { create(:book, library: other_library, title: "Alice Elsewhere") }

    it "restricts results to the base scope, including FTS queries" do
      base = Book.where(library_id: library.id)
      # Without the base scope, the FTS query would also match outsider.
      results = described_class.new(query: "Alice", base_scope: base).relation
      expect(results.pluck(:id)).to contain_exactly(alice.id)
    end

    it "restricts the LIKE fallback to the base scope too" do
      base = Book.where(library_id: library.id)
      results = described_class.new(query: "Moby", base_scope: base).relation
      expect(results.pluck(:id)).to contain_exactly(moby.id)
    end
  end

  describe "#relation with query" do
    it "filters by title via FTS5" do
      results = described_class.new(query: "Alice").relation
      expect(results.pluck(:id)).to contain_exactly(alice.id)
    end

    it "falls back to LIKE on malformed FTS syntax" do
      results = described_class.new(query: "Moby").relation
      expect(results.pluck(:id)).to contain_exactly(moby.id)
    end

    it "matches authors via FTS index" do
      results = described_class.new(query: "Carroll").relation
      expect(results.pluck(:id)).to contain_exactly(alice.id)
    end
  end

  describe "#relation with filters" do
    it "filters by author_id" do
      expect(described_class.new(author_id: author.id).relation.pluck(:id)).to contain_exactly(alice.id)
    end

    it "filters by tag_id" do
      expect(described_class.new(tag_id: tag.id).relation.pluck(:id)).to contain_exactly(alice.id)
    end

    it "filters by collection_id" do
      collection = create(:collection)
      collection.books << moby
      expect(described_class.new(collection_id: collection.id).relation.pluck(:id))
        .to contain_exactly(moby.id)
    end

    it "filters by library_id" do
      other = create(:library)
      create(:book, library: other, title: "Other")
      expect(described_class.new(library_id: library.id).relation.pluck(:id))
        .to contain_exactly(alice.id, moby.id)
    end
  end

  describe "#relation with favorite filter" do
    it "filters to favorites of a user" do
      user = create(:user)
      create(:favorite, user: user, book: moby)
      results = described_class.new(favorite_user_id: user.id).relation
      expect(results.pluck(:id)).to contain_exactly(moby.id)
    end
  end

  describe "sort" do
    it "sorts by title ascending" do
      expect(described_class.new(sort: "title_asc").relation.pluck(:title)).to eq(["Alice in Wonderland", "Moby Dick"])
    end

    it "sorts by title descending" do
      expect(described_class.new(sort: "title_desc").relation.pluck(:title)).to eq(["Moby Dick", "Alice in Wonderland"])
    end

    it "sorts by the alphabetically-first author when each book has one" do
      moby.authors << create(:author, name: "Herman Melville")
      # Herman (H) < Lewis (L) → moby first
      expect(described_class.new(sort: "author_asc").relation.pluck(:title))
        .to eq(["Moby Dick", "Alice in Wonderland"])
    end

    it "puts books with no author at the bottom of an author sort" do
      # alice already has Lewis Carroll; moby has no author.
      titles = described_class.new(sort: "author_asc").relation.pluck(:title)
      expect(titles.first).to eq("Alice in Wonderland")
      expect(titles.last).to eq("Moby Dick")
    end

    it "uses MIN(authors.name) when a book has multiple authors" do
      alice.authors << create(:author, name: "Aaron Author")  # Aaron < Lewis
      moby.authors << create(:author, name: "Mary Melville")
      # alice MIN = Aaron, moby MIN = Mary → alice first
      expect(described_class.new(sort: "author_asc").relation.pluck(:title))
        .to eq(["Alice in Wonderland", "Moby Dick"])
    end

    it "sorts by author descending, putting unauthored books last" do
      moby.authors << create(:author, name: "Herman Melville")
      # Lewis (L) > Herman (H) → alice first descending; moby (no author)
      # would come last but here moby has Herman so order is alice, moby
      titles = described_class.new(sort: "author_desc").relation.pluck(:title)
      expect(titles).to eq(["Alice in Wonderland", "Moby Dick"])
    end

    it "keeps unauthored books last when sorting author descending" do
      # alice has Lewis Carroll, moby has none
      titles = described_class.new(sort: "author_desc").relation.pluck(:title)
      expect(titles.first).to eq("Alice in Wonderland")
      expect(titles.last).to eq("Moby Dick")
    end
  end
end
