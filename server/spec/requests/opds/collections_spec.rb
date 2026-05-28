# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Collections", type: :request do
  include_context "opds feed request"

  ATOM = "http://www.w3.org/2005/Atom"

  describe "GET /opds/collections" do
    it "requires authentication" do
      get "/opds/collections"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the user's collections as a navigation feed" do
      create(:collection, user: user, name: "Manga")
      create(:collection, user: user, name: "Novels")
      create(:collection, user: create(:user), name: "TheirSecret")

      get "/opds/collections", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      titles = Nokogiri::XML(response.body).xpath("//atom:entry/atom:title", "atom" => ATOM).map(&:text)
      expect(titles).to contain_exactly("Manga", "Novels")
      expect(response.body).not_to include("TheirSecret")
    end
  end

  describe "GET /opds/collections/:id" do
    it "returns the collection's books as an acquisition feed" do
      collection = create(:collection, user: user, name: "Manga")
      collection.books << create(:book, library: library, title: "InCollection", file_path: "a.cbz")
      create(:book, library: library, title: "Outside", file_path: "b.cbz")

      get "/opds/collections/#{collection.id}", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      titles = Nokogiri::XML(response.body).xpath("//atom:entry/atom:title", "atom" => ATOM).map(&:text)
      expect(titles).to contain_exactly("InCollection")
    end

    it "404s for another user's collection" do
      other = create(:collection, user: create(:user))
      get "/opds/collections/#{other.id}", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /opds (root navigation)" do
    it "advertises the Collections subsection" do
      get "/opds", headers: {"Authorization" => auth_header}

      hrefs = Nokogiri::XML(response.body)
        .xpath("//atom:entry/atom:link", "atom" => ATOM).map { |l| l["href"] }
      expect(hrefs).to include("/opds/collections")
    end
  end
end
