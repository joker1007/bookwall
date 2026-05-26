require "rails_helper"

RSpec.describe "Opds::Pages", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials(user.email_address, "password123") }
  let(:library) { create(:library) }

  describe "GET /opds/books/:book_id/pages/:n" do
    let(:book) do
      create(:book,
             library: library,
             file_format: :cbz,
             file_path: Rails.root.join("spec/fixtures/files/sample.cbz").to_s,
             page_count: 4)
    end

    it "returns the requested page as image bytes" do
      get "/opds/books/#{book.id}/pages/1", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/jpeg")
      expect(response.body.bytesize).to be > 1000
    end

    it "returns 404 for out-of-range pages" do
      get "/opds/books/#{book.id}/pages/9999", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      get "/opds/books/#{book.id}/pages/1"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
