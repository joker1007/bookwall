# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::ReadingProgresses", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library) }
  let(:book) { create(:book, library: library, page_count: 20) }

  describe "GET /api/books/:book_id/progress" do
    it "requires authentication" do
      get "/api/books/#{book.id}/progress"
      expect(response).to have_http_status(:unauthorized)
    end

    context "when logged in" do
      before do
        post "/api/session",
          params: {email_address: user.email_address, password: password},
          as: :json
      end

      it "returns a blank progress when none is stored" do
        get "/api/books/#{book.id}/progress"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["current_page"]).to eq(0)
        expect(body["settings"]).to eq({})
        # The client uses last_read_at == null to detect a never-opened
        # book so it can apply the user-wide reader defaults instead.
        expect(body["last_read_at"]).to be_nil
      end

      it "returns the stored progress with settings" do
        ReadingProgress.create!(
          user: user, book: book,
          current_page: 7,
          last_read_at: Time.current,
          settings_json: '{"spread":true,"direction":"rtl"}'
        )

        get "/api/books/#{book.id}/progress"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["current_page"]).to eq(7)
        expect(body["settings"]).to eq("spread" => true, "direction" => "rtl")
      end
    end
  end

  describe "PATCH /api/books/:book_id/progress" do
    before do
      post "/api/session",
        params: {email_address: user.email_address, password: password},
        as: :json
    end

    it "round-trips epub_cfi" do
      patch "/api/books/#{book.id}/progress",
        params: {epub_cfi: "epubcfi(/6/4!/4/12/1:0)"},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["epub_cfi"]).to eq("epubcfi(/6/4!/4/12/1:0)")
      expect(book.reading_progresses.find_by(user: user).epub_cfi).to eq("epubcfi(/6/4!/4/12/1:0)")
    end

    it "round-trips progress_fraction" do
      patch "/api/books/#{book.id}/progress",
        params: {progress_fraction: 0.37},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["progress_fraction"]).to eq(0.37)
      expect(book.reading_progresses.find_by(user: user).progress_fraction).to eq(0.37)
    end

    it "creates progress when none exists" do
      expect {
        patch "/api/books/#{book.id}/progress",
          params: {current_page: 3},
          as: :json
      }.to change(ReadingProgress, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_page"]).to eq(3)
    end

    it "updates an existing progress without creating a duplicate" do
      ReadingProgress.create!(
        user: user, book: book, current_page: 1, last_read_at: 1.day.ago
      )

      expect {
        patch "/api/books/#{book.id}/progress",
          params: {current_page: 12, settings: {spread: true, direction: "ltr"}},
          as: :json
      }.not_to change(ReadingProgress, :count)

      body = response.parsed_body
      expect(body["current_page"]).to eq(12)
      expect(body["settings"]).to eq("spread" => true, "direction" => "ltr")
    end

    it "rejects negative current_page" do
      patch "/api/books/#{book.id}/progress",
        params: {current_page: -1},
        as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "isolates progress per user" do
      other = create(:user, password: password)
      ReadingProgress.create!(
        user: other, book: book, current_page: 99, last_read_at: Time.current
      )

      patch "/api/books/#{book.id}/progress",
        params: {current_page: 4},
        as: :json

      get "/api/books/#{book.id}/progress"
      expect(response.parsed_body["current_page"]).to eq(4)
    end
  end
end
