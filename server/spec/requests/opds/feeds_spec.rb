# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials(user.email_address, "password123") }
  let(:library) { create(:library) }

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
        file_path: "/mnt/books/epub-only.epub",
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
        file_path: "/mnt/books/x.epub", title: "EpubLink")
      cbz = create(:book, library: library, file_format: :cbz,
        file_path: "/mnt/books/x.cbz", title: "CbzLink")

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
        file_path: "/mnt/books/some-dir", title: "DirOnly")

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
        file_path: "/mnt/books/format-hints.epub",
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
        file_path: "/mnt/books/plain.epub", title: "PlainBook")

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
        file_path: "/mnt/books/no-cover.epub", title: "NoCover")

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
        file_path: "/mnt/books/imgdir",
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
end
