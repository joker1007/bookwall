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

    it "returns pageNumber=0 as the first page (OPDS-PSE numbers from 0)" do
      get "/opds/books/#{book.id}/pages/0", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/jpeg")
      expect(response.body.bytesize).to be > 1000
    end

    it "uses the actual MIME type of the page (PNG entry → image/png)" do
      # sample.cbz contains 001.jpg, 002.jpg, 003.jpg, peppercredit.png. The
      # PNG sorts last, so index 3 should come back as image/png rather than
      # the historical hard-coded image/jpeg.
      get "/opds/books/#{book.id}/pages/3", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
    end

    it "returns 404 for out-of-range pages" do
      get "/opds/books/#{book.id}/pages/9999", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:not_found)
    end

    it "rejects negative page numbers with 400" do
      get "/opds/books/#{book.id}/pages/-1", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:bad_request)
    end

    it "requires authentication" do
      get "/opds/books/#{book.id}/pages/0"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
