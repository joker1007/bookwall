require "rails_helper"

RSpec.describe "Opds::Downloads", type: :request do
  let(:user) { create(:user, password: "password123") }
  let(:auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials(user.email_address, "password123") }
  let(:library_path) { Rails.root.join("spec/fixtures/files").to_s }
  let(:library) { create(:library, path: library_path) }

  describe "GET /opds/books/:book_id/file.:format" do
    it "serves an EPUB with the .epub extension in the URL" do
      book = create(:book,
        library: library,
        file_format: :epub,
        title: "Sample EPUB",
        file_path: Rails.root.join("spec/fixtures/files/sample.epub").to_s)

      get "/opds/books/#{book.id}/file.epub", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/epub+zip")
      expect(response.headers["Content-Disposition"]).to include('filename="Sample EPUB.epub"')
    end

    it "serves a CBZ with the .cbz extension" do
      book = create(:book,
        library: library,
        file_format: :cbz,
        title: "Sample CBZ",
        file_path: Rails.root.join("spec/fixtures/files/sample.cbz").to_s)

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/x-cbz")
      expect(response.headers["Content-Disposition"]).to include('filename="Sample CBZ.cbz"')
    end

    it "rejects format that mismatches the book's actual file_format" do
      book = create(:book,
        library: library,
        file_format: :epub,
        file_path: Rails.root.join("spec/fixtures/files/sample.epub").to_s)

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for image_dir books (not downloadable)" do
      book = create(:book,
        library: library,
        file_format: :image_dir,
        file_path: Rails.root.join("spec/fixtures/files/sample_image_dir").to_s)

      # image_dir is not in the route constraint, so this path isn't reachable
      # via .epub/.cbz/.pdf either — even if a client tried, we 404.
      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      book = create(:book,
        library: library,
        file_format: :epub,
        file_path: Rails.root.join("spec/fixtures/files/sample.epub").to_s)

      get "/opds/books/#{book.id}/file.epub"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
