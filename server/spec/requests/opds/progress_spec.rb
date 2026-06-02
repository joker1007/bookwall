# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Progress", type: :request do
  include_context "opds feed request"

  let(:book) { create(:book, library: library, page_count: 24) }

  describe "PUT /opds/books/:book_id/progress" do
    it "requires authentication" do
      put "/opds/books/#{book.id}/progress", params: {current_page: 5}
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates progress for a page-based book via Basic auth" do
      put "/opds/books/#{book.id}/progress",
        params: {current_page: 5, progress_fraction: 0.25},
        headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      progress = ReadingProgress.find_by(user_id: user.id, book_id: book.id)
      expect(progress.current_page).to eq(5)
      expect(progress.progress_fraction).to be_within(0.001).of(0.25)
      expect(progress.last_read_at).to be_present
    end

    it "updates existing progress and refreshes last_read_at" do
      ReadingProgress.create!(user: user, book: book, current_page: 1, last_read_at: 1.day.ago)
      put "/opds/books/#{book.id}/progress",
        params: {current_page: 10},
        headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      expect(ReadingProgress.find_by(user_id: user.id, book_id: book.id).current_page).to eq(10)
    end

    it "rejects a negative page" do
      put "/opds/books/#{book.id}/progress",
        params: {current_page: -1},
        headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s for a book in an inaccessible library" do
      other = create(:book, library: create(:library))
      put "/opds/books/#{other.id}/progress",
        params: {current_page: 1},
        headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:not_found)
    end

    it "syncs an EPUB epub_cfi + progress_fraction" do
      epub = create(:book, library: library, file_format: "epub")
      put "/opds/books/#{epub.id}/progress",
        params: {epub_cfi: "epubcfi(/6/4!/4/12/1:0)", progress_fraction: 0.4},
        headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      progress = ReadingProgress.find_by(user_id: user.id, book_id: epub.id)
      expect(progress.epub_cfi).to eq("epubcfi(/6/4!/4/12/1:0)")
      expect(progress.progress_fraction).to be_within(0.001).of(0.4)
      expect(progress.current_page).to eq(0)
      expect(progress.last_read_at).to be_present
    end
  end

  describe "GET /opds/books/:book_id/progress" do
    it "requires authentication" do
      get "/opds/books/#{book.id}/progress"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the stored progress" do
      ReadingProgress.create!(
        user: user, book: book, current_page: 7,
        epub_cfi: "epubcfi(/6/4!/2)", progress_fraction: 0.3, last_read_at: 1.hour.ago
      )
      get "/opds/books/#{book.id}/progress", headers: {"Authorization" => auth_header}

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["current_page"]).to eq(7)
      expect(body["epub_cfi"]).to eq("epubcfi(/6/4!/2)")
      expect(body["progress_fraction"]).to be_within(0.001).of(0.3)
    end

    it "404s for a book in an inaccessible library" do
      other = create(:book, library: create(:library))
      get "/opds/books/#{other.id}/progress", headers: {"Authorization" => auth_header}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /opds (capability link)" do
    it "advertises the progress-sync endpoint with a {bookId} template" do
      get "/opds", headers: {"Authorization" => auth_header}

      doc = Nokogiri::XML(response.body)
      link = doc.at_xpath(
        "//atom:feed/atom:link[@rel='https://bookwall.joker1007.net/rel/progress-sync']",
        "atom" => "http://www.w3.org/2005/Atom"
      )
      expect(link).to be_present
      expect(link["href"]).to include("{bookId}")
      expect(link["type"]).to eq("application/json")
    end
  end
end
