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
end
