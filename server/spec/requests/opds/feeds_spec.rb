# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds", type: :request do
  include_context "opds feed request"

  ATOM_NS = "http://www.w3.org/2005/Atom"
  PSE_NS = "http://vaemendis.net/opds-pse/ns"

  def pse_link(body)
    Nokogiri::XML(body).at_xpath(
      "//atom:entry/pse:link[@rel='http://vaemendis.net/opds-pse/stream']",
      "atom" => ATOM_NS, "pse" => PSE_NS
    )
  end

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

    it "adds pse:lastRead (1-based) and pse:lastReadDate from the user's progress" do
      book = create(:book, library: library, page_count: 10)
      ReadingProgress.create!(
        user: user, book: book, current_page: 3, last_read_at: Time.utc(2026, 5, 29, 12, 0, 0)
      )

      get "/opds/recent", headers: {"Authorization" => auth_header}

      pse = pse_link(response.body)
      # current_page is 0-based; OPDS-PSE lastRead is 1-based, so 3 -> 4.
      expect(pse.attribute_with_ns("lastRead", PSE_NS).value).to eq("4")
      expect(pse.attribute_with_ns("lastReadDate", PSE_NS).value).to eq("2026-05-29T12:00:00Z")
    end

    it "omits pse:lastRead/lastReadDate when the user has no progress" do
      create(:book, library: library, page_count: 10)
      get "/opds/recent", headers: {"Authorization" => auth_header}

      pse = pse_link(response.body)
      expect(pse.attribute_with_ns("lastRead", PSE_NS)).to be_nil
      expect(pse.attribute_with_ns("lastReadDate", PSE_NS)).to be_nil
    end

    it "scopes pse:lastRead to the requesting user's own progress" do
      book = create(:book, library: library, page_count: 10)
      ReadingProgress.create!(user: create(:user), book: book, current_page: 5, last_read_at: Time.current)

      get "/opds/recent", headers: {"Authorization" => auth_header}

      expect(pse_link(response.body).attribute_with_ns("lastRead", PSE_NS)).to be_nil
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
end
