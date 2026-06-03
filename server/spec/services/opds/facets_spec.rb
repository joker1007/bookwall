# frozen_string_literal: true

require "rails_helper"

RSpec.describe Opds::Facets do
  let(:library) { create(:library) }
  let(:manga) { create(:tag, name: "manga") }
  let(:novel) { create(:tag, name: "novel") }
  let(:url_builder) do
    ->(tag_id:) { "/feed?tag_id=#{tag_id}" }
  end

  def facets_for(tag_id: nil)
    described_class.new(scope: library.books, tag_id: tag_id, url_builder: url_builder)
  end

  describe "#books" do
    it "returns the whole scope when no filter is active" do
      a = create(:book, library: library, file_path: "a.cbz")
      z = create(:book, library: library, file_path: "z.cbz")

      expect(facets_for.books).to contain_exactly(a, z)
    end

    it "filters by tag_id" do
      tagged = create(:book, library: library, file_path: "t.cbz")
      tagged.tags << manga
      _untagged = create(:book, library: library, file_path: "u.cbz")

      expect(facets_for(tag_id: manga.id).books).to contain_exactly(tagged)
    end
  end

  describe "#links" do
    it "lists each tag present in the scope with counts" do
      b1 = create(:book, library: library, file_path: "1.cbz")
      b1.tags << manga
      b2 = create(:book, library: library, file_path: "2.cbz")
      b2.tags << novel

      links = facets_for.links

      expect(links.map(&:group).uniq).to eq(["Tags"])
      expect(links.map { |f| [f.title, f.count] }).to eq([["manga", 1], ["novel", 1]])
    end

    it "omits the tag group entirely when the scope has no tags" do
      create(:book, library: library, file_path: "lonely.cbz")

      expect(facets_for.links).to be_empty
    end

    it "marks the active facet" do
      a = create(:book, library: library, file_path: "a.cbz")
      a.tags << manga
      z = create(:book, library: library, file_path: "z.cbz")
      z.tags << novel

      links = facets_for(tag_id: manga.id).links
      active = links.find(&:active)
      expect(active.title).to eq("manga")
      expect(links.reject { |f| f.title == "manga" }).to all(have_attributes(active: false))
    end

    it "builds the tag facet href from the url_builder" do
      book = create(:book, library: library, file_path: "a.cbz")
      book.tags << manga

      facet = facets_for.links.find { |f| f.title == "manga" }
      expect(facet.href).to eq("/feed?tag_id=#{manga.id}")
    end
  end
end
