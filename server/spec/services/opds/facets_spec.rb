# frozen_string_literal: true

require "rails_helper"

RSpec.describe Opds::Facets do
  let(:library) { create(:library) }
  let(:akira) { create(:series, library: library, name: "Akira") }
  let(:zelda) { create(:series, library: library, name: "Zelda") }
  let(:manga) { create(:tag, name: "manga") }
  let(:novel) { create(:tag, name: "novel") }
  let(:url_builder) do
    ->(series_id:, tag_id:) { "/feed?series_id=#{series_id}&tag_id=#{tag_id}" }
  end

  def facets_for(series_id: nil, tag_id: nil)
    described_class.new(scope: library.books, series_id: series_id, tag_id: tag_id, url_builder: url_builder)
  end

  describe "#books" do
    it "returns the whole scope when no filter is active" do
      a = create(:book, library: library, series: akira, file_path: "a.cbz")
      z = create(:book, library: library, series: zelda, file_path: "z.cbz")

      expect(facets_for.books).to contain_exactly(a, z)
    end

    it "filters by series_id" do
      a = create(:book, library: library, series: akira, file_path: "a.cbz")
      _z = create(:book, library: library, series: zelda, file_path: "z.cbz")

      expect(facets_for(series_id: akira.id).books).to contain_exactly(a)
    end

    it "filters by tag_id" do
      tagged = create(:book, library: library, file_path: "t.cbz")
      tagged.tags << manga
      _untagged = create(:book, library: library, file_path: "u.cbz")

      expect(facets_for(tag_id: manga.id).books).to contain_exactly(tagged)
    end

    it "combines series_id and tag_id with AND" do
      hit = create(:book, library: library, series: akira, file_path: "hit.cbz")
      hit.tags << manga
      miss_series = create(:book, library: library, series: zelda, file_path: "ms.cbz")
      miss_series.tags << manga
      miss_tag = create(:book, library: library, series: akira, file_path: "mt.cbz")

      result = facets_for(series_id: akira.id, tag_id: manga.id).books
      expect(result).to contain_exactly(hit)
    end
  end

  describe "#links" do
    it "lists each series and tag present in the scope with counts" do
      b1 = create(:book, library: library, series: akira, file_path: "1.cbz")
      b1.tags << manga
      b2 = create(:book, library: library, series: akira, file_path: "2.cbz")
      b2.tags << novel
      create(:book, library: library, series: zelda, file_path: "3.cbz")

      links = facets_for.links
      series = links.select { |f| f.group == "Series" }
      tags = links.select { |f| f.group == "Tags" }

      expect(series.map { |f| [f.title, f.count] }).to eq([["Akira", 2], ["Zelda", 1]])
      expect(tags.map { |f| [f.title, f.count] }).to eq([["manga", 1], ["novel", 1]])
    end

    it "omits a group entirely when the scope has no such metadata" do
      create(:book, library: library, file_path: "lonely.cbz")

      links = facets_for.links
      expect(links.map(&:group)).not_to include("Series")
      expect(links.map(&:group)).not_to include("Tags")
    end

    it "marks the active facet" do
      create(:book, library: library, series: akira, file_path: "a.cbz")
      create(:book, library: library, series: zelda, file_path: "z.cbz")

      links = facets_for(series_id: akira.id).links
      active = links.find(&:active)
      expect(active.title).to eq("Akira")
      expect(links.reject { |f| f.title == "Akira" }).to all(have_attributes(active: false))
    end

    it "scopes series counts to the active tag so combinations stay accurate" do
      a1 = create(:book, library: library, series: akira, file_path: "a1.cbz")
      a1.tags << manga
      a2 = create(:book, library: library, series: akira, file_path: "a2.cbz")
      a2.tags << novel
      z1 = create(:book, library: library, series: zelda, file_path: "z1.cbz")
      z1.tags << novel

      series = facets_for(tag_id: manga.id).links.select { |f| f.group == "Series" }
      # Only Akira has a manga-tagged book.
      expect(series.map { |f| [f.title, f.count] }).to eq([["Akira", 1]])
    end

    it "preserves the active tag in series facet hrefs" do
      book = create(:book, library: library, series: akira, file_path: "a.cbz")
      book.tags << manga

      series = facets_for(tag_id: manga.id).links.find { |f| f.group == "Series" }
      expect(series.href).to eq("/feed?series_id=#{akira.id}&tag_id=#{manga.id}")
    end
  end
end
