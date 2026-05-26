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
  end
end
