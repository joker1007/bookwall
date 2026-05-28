# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Authors", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }
  let(:library) { create(:library, owner: user) }

  before do
    post "/api/session",
         params: {email_address: user.email_address, password: password},
         as: :json
  end

  def create_author_with_books(name, book_count)
    author = create(:author, name: name)
    book_count.times do |j|
      book = create(:book, library: library, file_path: "#{name.parameterize}-#{j}.cbz")
      book.authors << author
    end
    author
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

  describe "GET /api/authors" do
    it "lists authors with their book counts and sample cover" do
      author = create(:author, name: "Alice")
      book = create(:book, library: library, file_path: "a.cbz")
      book.authors << author

      get "/api/authors"

      payload = response.parsed_body["authors"]
      expect(payload.size).to eq(1)
      expect(payload[0]["name"]).to eq("Alice")
      expect(payload[0]["book_count"]).to eq(1)
    end

    it "keeps the query count flat as more authors are listed (no N+1)" do
      create_author_with_books("First", 2)
      baseline = count_queries { get "/api/authors" }

      4.times { |i| create_author_with_books("Extra #{i}", 2) }
      scaled = count_queries { get "/api/authors" }

      payload = response.parsed_body["authors"]
      expect(payload.size).to eq(5)
      expect(payload.map { |a| a["book_count"] }).to all(eq(2))
      # book_count + sample cover resolve in a fixed set of batched queries,
      # so adding authors must not add queries.
      expect(scaled).to eq(baseline)
    end
  end
end
