# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library, owner: user) }

  describe "GET /api/books" do
    it_behaves_like "requires authentication", :get, "/api/books"

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

    it "returns the stored progress_fraction for EPUB books" do
      sign_in!
      epub = create(:book, library: library, file_format: :epub, page_count: 20)
      ReadingProgress.create!(user: user, book: epub, current_page: 0,
        last_read_at: 1.hour.ago, epub_cfi: "epubcfi(/6/4!/4/2)",
        progress_fraction: 0.42)

      get "/api/books"
      progress = response.parsed_body["books"].first["reading_progress"]
      expect(progress["fraction"]).to eq(0.42)
      expect(progress["last_read_at"]).to be_present
    end

    it "returns a nil fraction for EPUB books with no stored progress_fraction" do
      sign_in!
      epub = create(:book, library: library, file_format: :epub, page_count: 20)
      ReadingProgress.create!(user: user, book: epub, current_page: 0,
        last_read_at: 1.hour.ago, epub_cfi: "epubcfi(/6/4!/4/2)")

      get "/api/books"
      progress = response.parsed_body["books"].first["reading_progress"]
      expect(progress["fraction"]).to be_nil
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

    it "returns 422 when the title is blank" do
      sign_in!
      book = create(:book, library: library, title: "Old")

      patch "/api/books/#{book.id}", params: {title: ""}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(book.reload.title).to eq("Old")
    end

    it "rolls back the metadata write when associating tags fails" do
      sign_in!
      book = create(:book, library: library, title: "Old")
      allow(Tag).to receive(:upsert_all).and_raise(ActiveRecord::RecordInvalid.new(Tag.new))

      patch "/api/books/#{book.id}",
            params: {title: "New", tag_names: ["fantasy"]},
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(book.reload.title).to eq("Old")
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

  describe "GET /api/books?collection_id=" do
    it "filters to books in the user's own collection" do
      sign_in!
      collection = create(:collection, user: user)
      inside = create(:book, library: library, title: "Inside", file_path: "in.cbz")
      create(:book, library: library, title: "Outside", file_path: "out.cbz")
      collection.books << inside

      get "/api/books", params: {collection_id: collection.id}
      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to contain_exactly("Inside")
    end

    it "returns 404 for another user's collection (no curation leak)" do
      sign_in!
      other = create(:collection, user: create(:user))
      get "/api/books", params: {collection_id: other.id}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "bulk favorite" do
    it "favorites every selected accessible book and is idempotent" do
      sign_in!
      a = create(:book, library: library, file_path: "a.cbz")
      b = create(:book, library: library, file_path: "b.cbz")
      create(:favorite, user: user, book: a) # already favorited

      post "/api/books/bulk_favorite", params: {book_ids: [a.id, b.id]}, as: :json
      expect(response).to have_http_status(:no_content)
      expect(Favorite.where(user: user).pluck(:book_id)).to contain_exactly(a.id, b.id)
    end

    it "removes favorites for the selected books on DELETE" do
      sign_in!
      a = create(:book, library: library, file_path: "a.cbz")
      b = create(:book, library: library, file_path: "b.cbz")
      create(:favorite, user: user, book: a)
      create(:favorite, user: user, book: b)

      delete "/api/books/bulk_favorite", params: {book_ids: [a.id, b.id]}, as: :json
      expect(response).to have_http_status(:no_content)
      expect(Favorite.where(user: user)).to be_empty
    end
  end

  describe "bulk destroy" do
    it "deletes owned books only, leaving shared (read-only) books intact" do
      sign_in!
      owned = create(:book, library: library, file_path: "owned.cbz")
      shared_lib = create(:library, owner: create(:user))
      create(:library_share, library: shared_lib, user: user)
      shared = create(:book, library: shared_lib, file_path: "shared.cbz")

      post "/api/books/bulk_destroy", params: {book_ids: [owned.id, shared.id]}, as: :json
      expect(response).to have_http_status(:no_content)
      expect(Book.exists?(owned.id)).to be(false)
      expect(Book.exists?(shared.id)).to be(true)
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
    let(:lib) { create(:library, path: Rails.root.join("spec/fixtures/files").to_s, owner: user) }

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

    it "advertises range support on the full response" do
      sign_in!
      book = create(:book, library: lib, file_format: :pdf,
        file_path: "sample.pdf")

      get "/api/books/#{book.id}/file"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Accept-Ranges"]).to eq("bytes")
    end

    it "serves a 206 partial response for a byte range" do
      sign_in!
      book = create(:book, library: lib, file_format: :pdf,
        file_path: "sample.pdf")
      full = Rails.root.join("spec/fixtures/files/sample.pdf").binread
      total = full.bytesize

      get "/api/books/#{book.id}/file", headers: {"Range" => "bytes=0-9"}

      expect(response).to have_http_status(:partial_content)
      expect(response.headers["Content-Range"]).to eq("bytes 0-9/#{total}")
      expect(response.body.bytesize).to eq(10)
      expect(response.body.b).to eq(full.byteslice(0, 10))
    end

    it "returns 416 for an unsatisfiable range" do
      sign_in!
      book = create(:book, library: lib, file_format: :pdf,
        file_path: "sample.pdf")
      total = Rails.root.join("spec/fixtures/files/sample.pdf").size

      get "/api/books/#{book.id}/file", headers: {"Range" => "bytes=#{total + 10}-#{total + 20}"}

      expect(response).to have_http_status(:range_not_satisfiable)
      expect(response.headers["Content-Range"]).to eq("bytes */#{total}")
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

  describe "GET /api/books/:id/next_in_series" do
    let(:series) { create(:series, library: library) }

    it_behaves_like "requires authentication", :get, "/api/books/1/next_in_series"

    it "returns the next book in the series by volume" do
      sign_in!
      vol1 = create(:book, library: library, series: series, volume: 1)
      vol2 = create(:book, library: library, series: series, volume: 2)

      get "/api/books/#{vol1.id}/next_in_series"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(vol2.id)
    end

    it "returns 204 when this is the last volume" do
      sign_in!
      create(:book, library: library, series: series, volume: 1)
      vol2 = create(:book, library: library, series: series, volume: 2)

      get "/api/books/#{vol2.id}/next_in_series"

      expect(response).to have_http_status(:no_content)
    end

    it "returns 204 when the book has no series" do
      sign_in!
      book = create(:book, library: library, series: nil)

      get "/api/books/#{book.id}/next_in_series"

      expect(response).to have_http_status(:no_content)
    end

    it "does not cross into another user's library" do
      sign_in!
      other_library = create(:library)
      other_series = create(:series, library: other_library)
      book = create(:book, library: other_library, series: other_series, volume: 1)
      create(:book, library: other_library, series: other_series, volume: 2)

      get "/api/books/#{book.id}/next_in_series"

      expect(response).to have_http_status(:not_found)
    end
  end
end
