# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::RecentReads", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library, owner: user) }

  describe "GET /api/recent_reads" do
    it_behaves_like "requires authentication", :get, "/api/recent_reads"

    it "returns books ordered by most recent last_read_at" do
      sign_in!

      older = create(:book, library: library, title: "Older", file_path: "older.cbz")
      newer = create(:book, library: library, title: "Newer", file_path: "newer.cbz")
      ReadingProgress.create!(user: user, book: older, last_read_at: 2.days.ago)
      ReadingProgress.create!(user: user, book: newer, last_read_at: 5.minutes.ago)

      get "/api/recent_reads"

      expect(response).to have_http_status(:ok)
      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to eq(["Newer", "Older"])
    end

    it "scopes results to the current user" do
      sign_in!

      other = create(:user)
      mine = create(:book, library: library, title: "Mine", file_path: "mine.cbz")
      stranger = create(:book, library: library, title: "Stranger", file_path: "s.cbz")
      ReadingProgress.create!(user: user, book: mine, last_read_at: 1.hour.ago)
      ReadingProgress.create!(user: other, book: stranger, last_read_at: 5.minutes.ago)

      get "/api/recent_reads"

      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to eq(["Mine"])
    end

    it "caps the result at #{Api::RecentReadsController::LIMIT} items" do
      sign_in!

      (Api::RecentReadsController::LIMIT + 5).times do |i|
        book = create(:book, library: library, title: "B#{i}", file_path: "b#{i}.cbz")
        ReadingProgress.create!(user: user, book: book, last_read_at: i.minutes.ago)
      end

      get "/api/recent_reads"

      expect(response.parsed_body["books"].length).to eq(Api::RecentReadsController::LIMIT)
    end
  end
end
