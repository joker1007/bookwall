# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::RecentReads", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library) }

  def sign_in!
    post "/api/session", params: {email_address: user.email_address, password: password}
    expect(response).to have_http_status(:created)
  end

  describe "GET /api/recent_reads" do
    it "requires authentication" do
      get "/api/recent_reads"
      expect(response).to have_http_status(:unauthorized)
    end

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

    it "caps the result at 12 items" do
      sign_in!

      15.times do |i|
        book = create(:book, library: library, title: "B#{i}", file_path: "b#{i}.cbz")
        ReadingProgress.create!(user: user, book: book, last_read_at: i.minutes.ago)
      end

      get "/api/recent_reads"

      expect(response.parsed_body["books"].length).to eq(12)
    end
  end
end
