# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds facets", type: :request do
  include_context "opds feed request"

  let(:akira) { create(:series, library: library, name: "Akira") }
  let(:zelda) { create(:series, library: library, name: "Zelda") }
  let(:manga) { create(:tag, name: "manga") }
  let(:opds_ns) { "http://opds-spec.org/2010/catalog" }
  let(:thr_ns) { "http://purl.org/syndication/thread/1.0" }
  let(:atom_ns) { "http://www.w3.org/2005/Atom" }

  def facet_links(body)
    Nokogiri::XML(body).xpath("//atom:link[@rel='http://opds-spec.org/facet']", "atom" => atom_ns)
  end

  def group_of(link) = link.attribute_with_ns("facetGroup", opds_ns)&.value
  def count_of(link) = link.attribute_with_ns("count", thr_ns)&.value
  def active?(link) = link.attribute_with_ns("activeFacet", opds_ns)&.value == "true"

  it "advertises series and tag facets in a library feed" do
    a = create(:book, library: library, series: akira, file_path: "a.cbz", title: "A")
    a.tags << manga
    create(:book, library: library, series: zelda, file_path: "z.cbz", title: "Z")

    get "/opds/libraries/#{library.id}", headers: {"Authorization" => auth_header}

    links = facet_links(response.body)
    series = links.select { |l| group_of(l) == "Series" }
    tags = links.select { |l| group_of(l) == "Tags" }

    expect(series.map { |l| l["title"] }).to eq(%w[Akira Zelda])
    expect(series.map { |l| l["href"] }).to eq([
      "/opds/libraries/#{library.id}?series_id=#{akira.id}",
      "/opds/libraries/#{library.id}?series_id=#{zelda.id}"
    ])
    expect(series.find { |l| l["title"] == "Akira" }.then { |l| count_of(l) }).to eq("1")
    expect(tags.map { |l| l["title"] }).to eq(%w[manga])
  end

  it "filters the library feed by series_id and marks the active facet" do
    create(:book, library: library, series: akira, file_path: "a.cbz", title: "InAkira")
    create(:book, library: library, series: zelda, file_path: "z.cbz", title: "InZelda")

    get "/opds/libraries/#{library.id}", params: {series_id: akira.id}, headers: {"Authorization" => auth_header}

    doc = Nokogiri::XML(response.body)
    titles = doc.xpath("//atom:entry/atom:title", "atom" => atom_ns).map(&:text)
    expect(titles).to contain_exactly("InAkira")

    active = facet_links(response.body).select { |l| active?(l) }
    expect(active.map { |l| l["title"] }).to eq(["Akira"])
  end

  it "filters the library feed by tag_id" do
    tagged = create(:book, library: library, file_path: "t.cbz", title: "Tagged")
    tagged.tags << manga
    create(:book, library: library, file_path: "u.cbz", title: "Untagged")

    get "/opds/libraries/#{library.id}", params: {tag_id: manga.id}, headers: {"Authorization" => auth_header}

    doc = Nokogiri::XML(response.body)
    titles = doc.xpath("//atom:entry/atom:title", "atom" => atom_ns).map(&:text)
    expect(titles).to contain_exactly("Tagged")
  end

  it "carries the active tag into the series facet hrefs" do
    book = create(:book, library: library, series: akira, file_path: "a.cbz")
    book.tags << manga

    get "/opds/libraries/#{library.id}", params: {tag_id: manga.id}, headers: {"Authorization" => auth_header}

    series = facet_links(response.body).find { |l| group_of(l) == "Series" }
    expect(series["href"]).to eq("/opds/libraries/#{library.id}?series_id=#{akira.id}&tag_id=#{manga.id}")
  end

  it "scopes favorites facets to the user's favorites" do
    mine = create(:book, library: library, series: akira, file_path: "m.cbz", title: "Mine")
    mine.tags << manga
    other = create(:book, library: library, series: zelda, file_path: "o.cbz", title: "Other")
    other.tags << manga
    create(:favorite, user: user, book: mine)

    get "/opds/favorites", headers: {"Authorization" => auth_header}

    links = facet_links(response.body)
    expect(links.select { |l| group_of(l) == "Series" }.map { |l| l["title"] }).to eq(%w[Akira])
    tag = links.find { |l| group_of(l) == "Tags" && l["title"] == "manga" }
    expect(count_of(tag)).to eq("1")
    expect(links.map { |l| l["href"] }).to all(start_with("/opds/favorites?"))
  end

  it "filters favorites by facet" do
    a = create(:book, library: library, series: akira, file_path: "a.cbz", title: "FavA")
    z = create(:book, library: library, series: zelda, file_path: "z.cbz", title: "FavZ")
    create(:favorite, user: user, book: a)
    create(:favorite, user: user, book: z)

    get "/opds/favorites", params: {series_id: zelda.id}, headers: {"Authorization" => auth_header}

    titles = Nokogiri::XML(response.body).xpath("//atom:entry/atom:title", "atom" => atom_ns).map(&:text)
    expect(titles).to contain_exactly("FavZ")
  end
end
