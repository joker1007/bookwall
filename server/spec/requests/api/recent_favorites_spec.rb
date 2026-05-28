# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::RecentFavorites", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library, owner: user) }

  describe "GET /api/recent_favorites" do
    it "requires authentication" do
      get "/api/recent_favorites"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns books ordered by most recent favorite creation time" do
      sign_in!

      older = create(:book, library: library, title: "Older", file_path: "older.cbz")
      newer = create(:book, library: library, title: "Newer", file_path: "newer.cbz")
      Favorite.create!(user: user, book: older, created_at: 2.days.ago)
      Favorite.create!(user: user, book: newer, created_at: 5.minutes.ago)

      get "/api/recent_favorites"

      expect(response).to have_http_status(:ok)
      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to eq(["Newer", "Older"])
    end

    it "scopes results to the current user" do
      sign_in!

      other = create(:user)
      mine = create(:book, library: library, title: "Mine", file_path: "mine.cbz")
      stranger = create(:book, library: library, title: "Stranger", file_path: "s.cbz")
      Favorite.create!(user: user, book: mine, created_at: 1.hour.ago)
      Favorite.create!(user: other, book: stranger, created_at: 5.minutes.ago)

      get "/api/recent_favorites"

      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to eq(["Mine"])
    end

    it "caps the result at #{Api::RecentFavoritesController::LIMIT} items" do
      sign_in!

      (Api::RecentFavoritesController::LIMIT + 5).times do |i|
        book = create(:book, library: library, title: "B#{i}", file_path: "b#{i}.cbz")
        Favorite.create!(user: user, book: book, created_at: i.minutes.ago)
      end

      get "/api/recent_favorites"

      expect(response.parsed_body["books"].length).to eq(Api::RecentFavoritesController::LIMIT)
    end

    it "marks each returned book as favorited" do
      sign_in!

      book = create(:book, library: library, file_path: "fav.cbz")
      Favorite.create!(user: user, book: book)

      get "/api/recent_favorites"

      expect(response.parsed_body["books"].first["favorited"]).to be(true)
    end
  end
end
