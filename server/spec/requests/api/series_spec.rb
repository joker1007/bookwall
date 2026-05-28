# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Series", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library) }

  before do
    post "/api/session",
      params: {email_address: user.email_address, password: password},
      as: :json
  end

  def count_queries
    count = 0
    callback = lambda do |_n, _start, _finish, _id, payload|
      next if /SCHEMA|TRANSACTION|SAVEPOINT|RELEASE/.match?(payload[:sql])
      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end

  describe "GET /api/series" do
    it "lists series with book counts and sample cover URL" do
      series = Series.create!(library: library, name: "S1")
      create(:book, library: library, series: series)
      get "/api/series"

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body["series"]
      expect(payload.size).to eq(1)
      expect(payload[0]["name"]).to eq("S1")
      expect(payload[0]["book_count"]).to eq(1)
      expect(payload[0]).to have_key("sample_cover_thumb_url")
    end

    it "keeps the query count flat as more series are listed (no N+1)" do
      first = Series.create!(library: library, name: "S0")
      create_list(:book, 2, library: library, series: first)
      baseline = count_queries { get "/api/series" }

      4.times do |i|
        series = Series.create!(library: library, name: "S#{i + 1}")
        create_list(:book, 2, library: library, series: series)
      end
      scaled = count_queries { get "/api/series" }

      payload = response.parsed_body["series"]
      expect(payload.size).to eq(5)
      expect(payload.map { |s| s["book_count"] }).to all(eq(2))
      expect(scaled).to eq(baseline)
    end
  end

  describe "DELETE /api/series/:id" do
    it "removes the series and cascades into its books" do
      series = Series.create!(library: library, name: "Cascade")
      create_list(:book, 3, library: library, series: series)

      expect {
        delete "/api/series/#{series.id}"
      }.to change(Series, :count).by(-1).and change(Book, :count).by(-3)
      expect(response).to have_http_status(:no_content)
    end

    it "requires authentication" do
      series = Series.create!(library: library, name: "Guarded")
      delete "/api/session"  # log out
      delete "/api/series/#{series.id}"

      expect(response).to have_http_status(:unauthorized)
      expect(Series.exists?(series.id)).to be true
    end
  end
end
