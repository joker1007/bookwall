# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Collections", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library, owner: user) }

  describe "GET /api/collections" do
    it_behaves_like "requires authentication", :get, "/api/collections"

    it "lists the current user's collections with book counts" do
      sign_in!
      mine = create(:collection, user: user, name: "Mine")
      mine.books << create(:book, library: library, file_path: "a.cbz")
      create(:collection, user: create(:user), name: "Theirs")

      get "/api/collections"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["collections"].map { |c| c["name"] }).to eq(["Mine"])
      expect(body["collections"].first["book_count"]).to eq(1)
    end
  end

  describe "POST /api/collections" do
    it "creates a collection owned by the current user" do
      sign_in!
      expect {
        post "/api/collections", params: {name: "Reading list"}, as: :json
      }.to change { user.collections.count }.by(1)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Reading list")
    end

    it "rejects a blank name" do
      sign_in!
      post "/api/collections", params: {name: ""}, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/collections/:id" do
    it "renames the collection" do
      sign_in!
      collection = create(:collection, user: user, name: "Old")
      patch "/api/collections/#{collection.id}", params: {name: "New"}, as: :json
      expect(response).to have_http_status(:ok)
      expect(collection.reload.name).to eq("New")
    end

    it "returns 404 for another user's collection" do
      sign_in!
      other = create(:collection, user: create(:user))
      patch "/api/collections/#{other.id}", params: {name: "Hijack"}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/collections/:id" do
    it "removes the collection but leaves its books" do
      sign_in!
      collection = create(:collection, user: user)
      collection.books << create(:book, library: library, file_path: "a.cbz")

      expect { delete "/api/collections/#{collection.id}" }
        .to change(Collection, :count).by(-1)
        .and change(Book, :count).by(0)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /api/collections/:collection_id/books" do
    it "adds accessible books to the collection (idempotent)" do
      sign_in!
      collection = create(:collection, user: user)
      a = create(:book, library: library, file_path: "a.cbz")
      b = create(:book, library: library, file_path: "b.cbz")

      post "/api/collections/#{collection.id}/books", params: {book_ids: [a.id, b.id]}, as: :json
      expect(response).to have_http_status(:no_content)
      expect(collection.reload.books).to match_array([a, b])

      # Re-adding is a no-op.
      post "/api/collections/#{collection.id}/books", params: {book_ids: [a.id]}, as: :json
      expect(collection.reload.books.count).to eq(2)
    end

    it "ignores books the user cannot access" do
      sign_in!
      collection = create(:collection, user: user)
      inaccessible = create(:book, library: create(:library, owner: create(:user)), file_path: "x.cbz")

      post "/api/collections/#{collection.id}/books", params: {book_ids: [inaccessible.id]}, as: :json
      expect(collection.reload.books).to be_empty
    end

    it "returns 404 when adding to another user's collection" do
      sign_in!
      other = create(:collection, user: create(:user))
      book = create(:book, library: library, file_path: "a.cbz")
      post "/api/collections/#{other.id}/books", params: {book_ids: [book.id]}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/collections/:collection_id/books/:id" do
    it "removes a single book from the collection" do
      sign_in!
      collection = create(:collection, user: user)
      book = create(:book, library: library, file_path: "a.cbz")
      collection.books << book

      delete "/api/collections/#{collection.id}/books/#{book.id}"
      expect(response).to have_http_status(:no_content)
      expect(collection.reload.books).to be_empty
    end
  end
end
