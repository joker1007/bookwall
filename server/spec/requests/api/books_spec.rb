# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library) }

  def sign_in!
    post "/api/session",
         params: {email_address: user.email_address, password: password},
         as: :json
  end

  describe "GET /api/books" do
    it "requires authentication" do
      get "/api/books"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists books with pagination metadata" do
      sign_in!
      create_list(:book, 3, library: library)

      get "/api/books"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["books"].size).to eq(3)
      expect(response.parsed_body["pagination"]).to include("page", "pages", "count")
    end

    it "searches via q parameter" do
      sign_in!
      create(:book, library: library, title: "Findable Adventure")
      create(:book, library: library, title: "Unrelated")

      get "/api/books", params: {q: "Findable"}
      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to eq(["Findable Adventure"])
    end

    it "respects favorites_only" do
      sign_in!
      book = create(:book, library: library)
      create(:book, library: library)
      create(:favorite, user: user, book: book)

      get "/api/books", params: {favorites_only: true}
      ids = response.parsed_body["books"].map { |b| b["id"] }
      expect(ids).to eq([book.id])
    end

    it "exposes reading_progress when the signed-in user has opened the book" do
      sign_in!
      read = create(:book, library: library, file_format: :cbz, page_count: 11)
      _untouched = create(:book, library: library, file_format: :cbz, page_count: 5)
      ReadingProgress.create!(user: user, book: read, current_page: 5,
        last_read_at: 1.hour.ago)

      get "/api/books", params: {sort: "added_at_asc"}
      progresses = response.parsed_body["books"].map { |b| b["reading_progress"] }
      expect(progresses.first).to include(
        "fraction" => 0.5,
        "current_page" => 5
      )
      expect(progresses.first["last_read_at"]).to be_present
      expect(progresses.last).to be_nil
    end

    it "returns a nil fraction for EPUB progress (no precise signal yet)" do
      sign_in!
      epub = create(:book, library: library, file_format: :epub, page_count: 20)
      ReadingProgress.create!(user: user, book: epub, current_page: 0,
        last_read_at: 1.hour.ago, epub_cfi: "epubcfi(/6/4!/4/2)")

      get "/api/books"
      progress = response.parsed_body["books"].first["reading_progress"]
      expect(progress["fraction"]).to be_nil
      expect(progress["last_read_at"]).to be_present
    end
  end

  describe "PATCH /api/books/:id" do
    it "updates metadata and author names" do
      sign_in!
      book = create(:book, library: library, title: "Old")

      patch "/api/books/#{book.id}",
            params: {title: "New", author_names: ["Alice", "Bob"], tag_names: ["fantasy"]},
            as: :json

      expect(response).to have_http_status(:ok)
      book.reload
      expect(book.title).to eq("New")
      expect(book.authors.pluck(:name)).to contain_exactly("Alice", "Bob")
      expect(book.tags.pluck(:name)).to contain_exactly("fantasy")
    end
  end

  describe "DELETE /api/books/:id" do
    it "removes only the metadata" do
      sign_in!
      book = create(:book, library: library)

      expect { delete "/api/books/#{book.id}" }.to change(Book, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "favorite toggle" do
    it "is idempotent on repeated POST" do
      sign_in!
      book = create(:book, library: library)

      2.times do
        post "/api/books/#{book.id}/favorite"
      end
      expect(Favorite.where(user: user, book: book).count).to eq(1)
    end

    it "removes the favorite on DELETE" do
      sign_in!
      book = create(:book, library: library)
      create(:favorite, user: user, book: book)

      delete "/api/books/#{book.id}/favorite"
      expect(response).to have_http_status(:no_content)
      expect(Favorite.where(user: user, book: book)).to be_empty
    end
  end

  describe "GET /api/books/:id/file" do
    let(:lib) { create(:library, path: Rails.root.join("spec/fixtures/files").to_s) }

    it "requires authentication" do
      book = create(:book, library: lib, file_format: :epub,
        file_path: "sample.epub")
      get "/api/books/#{book.id}/file"
      expect(response).to have_http_status(:unauthorized)
    end

    it "streams an EPUB with the correct MIME and filename" do
      sign_in!
      book = create(:book, library: lib, file_format: :epub, title: "Sample Book",
        file_path: "sample.epub")

      get "/api/books/#{book.id}/file"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/epub+zip")
      expect(response.headers["Content-Disposition"]).to include('filename="Sample Book.epub"')
      expect(response.headers["Cache-Control"]).to include("immutable")
      expect(response.headers["ETag"]).to be_present
    end

    it "returns 304 when If-None-Match matches the ETag" do
      sign_in!
      book = create(:book, library: lib, file_format: :epub,
        file_path: "sample.epub")

      get "/api/books/#{book.id}/file"
      etag = response.headers["ETag"]
      expect(etag).to be_present

      get "/api/books/#{book.id}/file", headers: {"If-None-Match" => etag}
      expect(response).to have_http_status(:not_modified)
    end

    it "returns 404 for image_dir books (not a single file)" do
      sign_in!
      book = create(:book, library: lib, file_format: :image_dir,
        file_path: "sample_image_dir")

      get "/api/books/#{book.id}/file"
      expect(response).to have_http_status(:not_found)
    end

    it "refuses to serve paths outside the library root" do
      sign_in!
      # A relative path that climbs above the library root resolves outside it.
      book = create(:book, library: lib, file_format: :epub,
        file_path: "../../README.md")

      get "/api/books/#{book.id}/file"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
