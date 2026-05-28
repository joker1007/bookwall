# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Tags", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

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

  describe "GET /api/tags" do
    it "lists tags that have at least one accessible book" do
      library = create(:library, owner: user)
      2.times do |i|
        tag = create(:tag, name: "tag-#{i}")
        create(:book, library: library, file_path: "b#{i}.cbz").tags << tag
      end
      get "/api/tags"
      expect(response.parsed_body["tags"].size).to eq(2)
    end

    it "keeps the query count flat as more tags are listed (no N+1)" do
      library = create(:library, owner: user)
      tag_with_books = ->(name) {
        tag = create(:tag, name: name)
        2.times { |j| create(:book, library: library, file_path: "#{name}-#{j}.cbz").tags << tag }
        tag
      }

      tag_with_books.call("t0")
      baseline = count_queries { get "/api/tags" }

      4.times { |i| tag_with_books.call("t#{i + 1}") }
      scaled = count_queries { get "/api/tags" }

      payload = response.parsed_body["tags"]
      expect(payload.size).to eq(5)
      expect(payload.map { |t| t["book_count"] }).to all(eq(2))
      expect(scaled).to eq(baseline)
    end
  end

  describe "PATCH /api/tags/:id" do
    it "renames a tag reachable through an owned library" do
      library = create(:library, owner: user)
      tag = create(:tag, name: "old")
      create(:book, library: library, file_path: "x.cbz").tags << tag
      patch "/api/tags/#{tag.id}", params: {name: "new"}, as: :json
      expect(tag.reload.name).to eq("new")
    end
  end

  describe "DELETE /api/tags/:id" do
    it "removes a tag reachable through an owned library" do
      library = create(:library, owner: user)
      tag = create(:tag)
      create(:book, library: library, file_path: "x.cbz").tags << tag
      expect { delete "/api/tags/#{tag.id}" }.to change(Tag, :count).by(-1)
    end
  end
end
