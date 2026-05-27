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
