require "rails_helper"

RSpec.describe "Api::Pages", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library) }
  let(:book) do
    create(:book,
      library: library,
      file_format: :cbz,
      file_path: Rails.root.join("spec/fixtures/files/sample.cbz").to_s,
      page_count: 4)
  end

  describe "GET /api/books/:book_id/pages/:n" do
    it "requires authentication" do
      get "/api/books/#{book.id}/pages/0"
      expect(response).to have_http_status(:unauthorized)
    end

    context "when logged in" do
      before do
        post "/api/session",
          params: {email_address: user.email_address, password: password},
          as: :json
      end

      it "returns the first page as image bytes (0-indexed)" do
        get "/api/books/#{book.id}/pages/0"

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("image/jpeg")
        expect(response.body.bytesize).to be > 1000
      end

      it "uses the entry's actual MIME (PNG → image/png)" do
        get "/api/books/#{book.id}/pages/3"
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("image/png")
      end

      it "404s for out-of-range pages" do
        get "/api/books/#{book.id}/pages/9999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
