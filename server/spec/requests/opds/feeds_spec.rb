# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials(user.email_address, "password123") }
  let(:library) { create(:library, owner: user) }

  describe "GET /opds" do
    it "requires authentication" do
      get "/opds"
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to match(/Basic/i)
    end

    it "accepts HTTP Basic auth and returns a navigation feed" do
      get "/opds", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to start_with("application/atom+xml")
      expect(response.body).to include("<title>Bookwall</title>")
    end

    it "accepts Bearer token auth" do
      token = ApiToken.issue!(user: user, name: "reader")
      get "/opds", headers: {"Authorization" => "Bearer #{token.plain_token}"}
      expect(response).to have_http_status(:ok)
    end

    it "rejects invalid Bearer token" do
      get "/opds", headers: {"Authorization" => "Bearer bogus"}
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /opds/recent" do
    it "lists books with PSE link including pse:count" do
      book = create(:book, library: library, title: "Sample", page_count: 24)
      get "/opds/recent", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sample")
      expect(response.body).to include('pse:count="24"')
      expect(response.body).to include("opds-pse/stream")
    end

    it "emits the OPDS-PSE href with a literal {pageNumber} template" do
      book = create(:book, library: library, page_count: 5)
      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      pse = doc.at_xpath(
        "//atom:entry/pse:link[@rel='http://vaemendis.net/opds-pse/stream']",
        "atom" => "http://www.w3.org/2005/Atom",
        "pse" => "http://vaemendis.net/opds-pse/ns"
      )
      expect(pse).not_to be_nil
      expect(pse["href"]).to eq("/opds/books/#{book.id}/pages/{pageNumber}")
      expect(pse["href"]).not_to include("%7B")
      expect(pse["href"]).not_to include("%7D")
    end

    it "omits the PSE link for EPUB books (PSE is image-only)" do
      create(:book,
        library: library,
        title: "EpubBook",
        file_format: :epub,
        file_path: "epub-only.epub",
        page_count: 12)
      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      entry = doc.at_xpath(
        "//atom:entry[atom:title='EpubBook']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      expect(entry).not_to be_nil
      pse = entry.at_xpath("pse:link", "pse" => "http://vaemendis.net/opds-pse/ns")
      expect(pse).to be_nil
    end

    it "puts the file extension on the acquisition href so readers can sniff EPUB" do
      epub = create(:book, library: library, file_format: :epub,
        file_path: "x.epub", title: "EpubLink")
      cbz = create(:book, library: library, file_format: :cbz,
        file_path: "x.cbz", title: "CbzLink")

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      acq = ->(entry_title) {
        doc.at_xpath(
          "//atom:entry[atom:title='#{entry_title}']/atom:link[@rel='http://opds-spec.org/acquisition']",
          "atom" => "http://www.w3.org/2005/Atom"
        )
      }
      expect(acq.call("EpubLink")["href"]).to eq("/opds/books/#{epub.id}/file.epub")
      expect(acq.call("EpubLink")["type"]).to eq("application/epub+zip")
      expect(acq.call("CbzLink")["href"]).to eq("/opds/books/#{cbz.id}/file.cbz")
      expect(acq.call("CbzLink")["type"]).to eq("application/x-cbz")
    end

    it "advertises image_dir books as CBZ acquisitions (packaged on the fly at download)" do
      book = create(:book, library: library, file_format: :image_dir,
        file_path: "some-dir", title: "DirOnly")

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      acq = doc.at_xpath(
        "//atom:entry[atom:title='DirOnly']/atom:link[@rel='http://opds-spec.org/acquisition']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      expect(acq).not_to be_nil
      expect(acq["href"]).to eq("/opds/books/#{book.id}/file.cbz")
      expect(acq["type"]).to eq("application/x-cbz")
    end

    it "exposes the file format via dc:format and atom:content for redundant detection" do
      create(:book,
        library: library,
        file_format: :epub,
        file_path: "format-hints.epub",
        title: "FormatHints",
        file_size: 4_300_000,
        page_count: 320)

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      ns = {
        "atom" => "http://www.w3.org/2005/Atom",
        "dc" => "http://purl.org/dc/elements/1.1/"
      }
      entry = doc.at_xpath("//atom:entry[atom:title='FormatHints']", ns)
      expect(entry.at_xpath("dc:format", ns)&.text).to eq("application/epub+zip")
      content = entry.at_xpath("atom:content[@type='text']", ns)&.text
      expect(content).to include("EPUB")
      expect(content).to include("320 pages")
      expect(content).to include("MB")
    end

    it "leaves atom:title untouched (no file extension suffix)" do
      # Some iOS OPDS clients display the entry title and an internally-derived
      # extension side by side, so adding ".epub" here would show up doubled.
      # Format detection must rely on acquisition link @type + dc:format +
      # atom:content instead.
      create(:book, library: library, file_format: :epub,
        file_path: "plain.epub", title: "PlainBook")

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      titles = doc.xpath(
        "//atom:entry/atom:title",
        "atom" => "http://www.w3.org/2005/Atom"
      ).map(&:text)
      expect(titles).to include("PlainBook")
      expect(titles).not_to include("PlainBook.epub")
    end

    it "emits placeholder cover + thumbnail links when the book has no attached cover" do
      create(:book, library: library, file_format: :epub,
        file_path: "no-cover.epub", title: "NoCover")

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      entry = doc.at_xpath(
        "//atom:entry[atom:title='NoCover']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      image = entry.at_xpath(
        "atom:link[@rel='http://opds-spec.org/image']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      thumb = entry.at_xpath(
        "atom:link[@rel='http://opds-spec.org/image/thumbnail']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      expect(image["href"]).to eq("/opds/placeholder-cover.jpg")
      expect(image["type"]).to eq("image/jpeg")
      expect(thumb["href"]).to eq("/opds/placeholder-thumb.jpg")
      expect(thumb["type"]).to eq("image/jpeg")
    end

    it "ships actual placeholder files in the public directory" do
      expect(Rails.public_path.join("opds/placeholder-cover.jpg")).to exist
      expect(Rails.public_path.join("opds/placeholder-thumb.jpg")).to exist
    end

    it "exposes image_dir to clients as CBZ via dc:format and atom:content" do
      create(:book,
        library: library,
        file_format: :image_dir,
        file_path: "imgdir",
        title: "ImgDirContent",
        page_count: 18)

      get "/opds/recent", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      ns = {
        "atom" => "http://www.w3.org/2005/Atom",
        "dc" => "http://purl.org/dc/elements/1.1/"
      }
      entry = doc.at_xpath("//atom:entry[atom:title='ImgDirContent']", ns)
      expect(entry.at_xpath("dc:format", ns)&.text).to eq("application/x-cbz")
      expect(entry.at_xpath("atom:content", ns)&.text).to start_with("CBZ")
    end
  end

  describe "GET /opds/libraries/:id" do
    it "returns books in the library" do
      create(:book, library: library, title: "OnlyOne")
      get "/opds/libraries/#{library.id}", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OnlyOne")
    end
  end

  describe "GET /opds/favorites" do
    it "returns only the user's favorites" do
      mine = create(:book, library: library, title: "Mine")
      _other = create(:book, library: library, title: "Other")
      create(:favorite, user: user, book: mine)

      get "/opds/favorites", headers: {"Authorization" => auth_header}

      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Other")
    end
  end

  describe "GET /opds/series" do
    it "lists every series as a navigation entry pointing at its books feed" do
      akira = create(:series, library: library, name: "Akira")
      zelda = create(:series, library: library, name: "Zelda")

      get "/opds/series", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to start_with("application/atom+xml")
      doc = Nokogiri::XML(response.body)
      ns = {"atom" => "http://www.w3.org/2005/Atom"}
      links = doc.xpath("//atom:entry/atom:link", ns).map { |l| l["href"] }
      # Sorted alphabetically.
      expect(links).to eq([
        "/opds/series/#{akira.id}",
        "/opds/series/#{zelda.id}"
      ])
    end
  end

  describe "GET /opds/series/:id" do
    it "lists books in the series ordered by volume then title" do
      series = create(:series, library: library, name: "Akira")
      vol2 = create(:book, library: library, series: series, title: "Akira v2", volume: 2, file_path: "akira-2.cbz")
      vol1 = create(:book, library: library, series: series, title: "Akira v1", volume: 1, file_path: "akira-1.cbz")
      other = create(:book, library: library, title: "Outside", file_path: "outside.cbz")

      get "/opds/series/#{series.id}", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      ns = {"atom" => "http://www.w3.org/2005/Atom"}
      titles = doc.xpath("//atom:entry/atom:title", ns).map(&:text)
      expect(titles).to eq([vol1.title, vol2.title])
      expect(titles).not_to include(other.title)
    end

    it "returns 404 for an unknown series" do
      get "/opds/series/999999", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /opds/tags" do
    it "lists every tag as a navigation entry pointing at its books feed" do
      manga = create(:tag, name: "manga")
      novel = create(:tag, name: "novel")
      create(:book, library: library, file_path: "m.cbz").tags << manga
      create(:book, library: library, file_path: "n.cbz").tags << novel

      get "/opds/tags", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      ns = {"atom" => "http://www.w3.org/2005/Atom"}
      links = doc.xpath("//atom:entry/atom:link", ns).map { |l| l["href"] }
      expect(links).to eq([
        "/opds/tags/#{manga.id}",
        "/opds/tags/#{novel.id}"
      ])
    end
  end

  describe "GET /opds/tags/:id" do
    it "lists only the books that carry the tag" do
      manga = create(:tag, name: "manga")
      tagged = create(:book, library: library, title: "Tagged", file_path: "tagged.cbz")
      tagged.tags << manga
      _untagged = create(:book, library: library, title: "Untagged", file_path: "untagged.cbz")

      get "/opds/tags/#{manga.id}", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::XML(response.body)
      ns = {"atom" => "http://www.w3.org/2005/Atom"}
      titles = doc.xpath("//atom:entry/atom:title", ns).map(&:text)
      expect(titles).to include("Tagged")
      expect(titles).not_to include("Untagged")
    end
  end

  describe "GET /opds (root navigation)" do
    it "advertises the new Series and Tags subsections" do
      get "/opds", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      ns = {"atom" => "http://www.w3.org/2005/Atom"}
      hrefs = doc.xpath("//atom:entry/atom:link", ns).map { |l| l["href"] }
      expect(hrefs).to include("/opds/series")
      expect(hrefs).to include("/opds/tags")
    end
  end

  describe "Content-Encoding negotiation" do
    it "leaves the feed uncompressed when no Accept-Encoding is sent" do
      get "/opds", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Encoding"]).to be_nil
      expect(response.headers["Vary"]).to include("Accept-Encoding")
      expect(response.body).to include("<title>Bookwall</title>")
    end

    {
      "gzip" => ->(body) { Zlib.gunzip(body) },
      "deflate" => ->(body) { Zlib::Inflate.inflate(body) },
      "br" => ->(body) { Brotli.inflate(body) },
      "zstd" => ->(body) { Zstd.decompress(body) }
    }.each do |encoding, decode|
      it "encodes the navigation feed with #{encoding} when requested" do
        get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => encoding}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Encoding"]).to eq(encoding)
        expect(response.headers["Vary"]).to include("Accept-Encoding")
        expect(decode.call(response.body)).to include("<title>Bookwall</title>")
      end

      it "encodes an acquisition feed with #{encoding} when requested" do
        create(:book, library: library, title: "Compressible", page_count: 10)
        get "/opds/recent", headers: {"Authorization" => auth_header, "Accept-Encoding" => encoding}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Encoding"]).to eq(encoding)
        expect(decode.call(response.body)).to include("Compressible")
      end
    end

    it "prefers zstd when the client offers several codecs equally" do
      get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "deflate, gzip, br, zstd"}

      expect(response.headers["Content-Encoding"]).to eq("zstd")
      expect(Zstd.decompress(response.body)).to include("<title>Bookwall</title>")
    end

    it "does not compress when only unsupported encodings are offered" do
      get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "compress"}

      expect(response.headers["Content-Encoding"]).to be_nil
      expect(response.body).to include("<title>Bookwall</title>")
    end
  end

  describe "Facets" do
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

  describe "Conditional GET via ETag" do
    it "sends a weak ETag on a navigation feed" do
      get "/opds", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.headers["ETag"]).to be_present
      expect(response.headers["ETag"]).to start_with('W/"')
    end

    it "returns 304 with no body when If-None-Match matches" do
      get "/opds", headers: {"Authorization" => auth_header}
      etag = response.headers["ETag"]

      get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag}

      expect(response).to have_http_status(:not_modified)
      expect(response.body).to be_empty
      expect(response.headers["Content-Encoding"]).to be_nil
    end

    it "skips compression entirely on a 304 even when an encoding is acceptable" do
      get "/opds", headers: {"Authorization" => auth_header}
      etag = response.headers["ETag"]

      expect(Opds::Compression).not_to receive(:encode)
      get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag, "Accept-Encoding" => "gzip"}

      expect(response).to have_http_status(:not_modified)
    end

    it "re-renders a 200 when the feed content has changed" do
      get "/opds/recent", headers: {"Authorization" => auth_header}
      etag = response.headers["ETag"]

      create(:book, library: library, title: "FreshlyAdded")
      get "/opds/recent", headers: {"Authorization" => auth_header, "If-None-Match" => etag}

      expect(response).to have_http_status(:ok)
      expect(response.headers["ETag"]).not_to eq(etag)
      expect(response.body).to include("FreshlyAdded")
    end

    it "matches the stored ETag regardless of the negotiated Content-Encoding" do
      get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "gzip"}
      etag = response.headers["ETag"]
      expect(response.headers["Content-Encoding"]).to eq("gzip")

      get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag, "Accept-Encoding" => "identity"}

      expect(response).to have_http_status(:not_modified)
    end
  end
end
