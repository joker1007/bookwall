# frozen_string_literal: true

require "rails_helper"
require "zip"

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

    it "packages image_dir books into an on-the-fly CBZ" do
      book = create(:book,
        library: library,
        file_format: :image_dir,
        title: "Image Dir Book",
        file_path: Rails.root.join("spec/fixtures/files/sample_image_dir").to_s)

      get "/opds/books/#{book.id}/file.cbz", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/x-cbz")
      expect(response.headers["Content-Disposition"]).to include('filename="Image Dir Book.cbz"')
      # Response body is a real zip with the directory's images repackaged.
      Zip::File.open_buffer(response.body) do |zip|
        names = zip.entries.map(&:name)
        expect(names).not_to be_empty
        names.each { |n| expect(n).to match(/\A\d{4}\.(jpg|jpeg|png|webp|gif)\z/i) }
      end
    end

    it "rejects an image_dir download requested with a non-cbz format" do
      book = create(:book,
        library: library,
        file_format: :image_dir,
        file_path: Rails.root.join("spec/fixtures/files/sample_image_dir").to_s)

      get "/opds/books/#{book.id}/file.epub", headers: {"Authorization" => auth_header}

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
