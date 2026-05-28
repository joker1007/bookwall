# frozen_string_literal: true

require "rails_helper"

# End-to-end access control for per-library sharing. Owner has full access,
# shared users are read-only, strangers see nothing (404, no existence leak).
RSpec.describe "Library sharing access control", type: :request do
  let(:password) { "password123" }
  let(:owner) { create(:user, email_address: "owner@example.com", password: password) }
  let(:shared) { create(:user, email_address: "shared@example.com", password: password) }
  let(:stranger) { create(:user, email_address: "stranger@example.com", password: password) }

  let(:library) { create(:library, owner: owner) }
  let!(:book) { create(:book, library: library, title: "InShared", file_path: "s.cbz") }

  before { create(:library_share, library: library, user: shared) }

  describe "GET /api/libraries" do
    it "lists only owned + shared libraries per viewer" do
      create(:library, owner: stranger, name: "Hidden", path: "/mnt/hidden")

      sign_in!(owner)
      get "/api/libraries"
      expect(response.parsed_body["libraries"].map { |l| l["id"] }).to contain_exactly(library.id)

      sign_in!(shared)
      get "/api/libraries"
      expect(response.parsed_body["libraries"].map { |l| l["id"] }).to contain_exactly(library.id)

      sign_in!(stranger)
      get "/api/libraries"
      ids = response.parsed_body["libraries"].map { |l| l["id"] }
      expect(ids).not_to include(library.id)
    end
  end

  describe "GET /api/libraries/:id" do
    it "200 for owner, 200 for shared, 404 for stranger" do
      sign_in!(owner)
      get "/api/libraries/#{library.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("can_manage" => true, "owner_id" => owner.id)

      sign_in!(shared)
      get "/api/libraries/#{library.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["can_manage"]).to be(false)
      expect(response.parsed_body["shared_user_ids"]).to eq([])

      sign_in!(stranger)
      get "/api/libraries/#{library.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/libraries" do
    it "assigns the creator as owner and syncs shares" do
      sign_in!(owner)
      post "/api/libraries",
        params: {name: "New", path: "/mnt/new", shared_user_ids: [shared.id]},
        as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["owner_id"]).to eq(owner.id)
      expect(body["can_manage"]).to be(true)
      expect(body["shared_user_ids"]).to contain_exactly(shared.id)
      created = Library.find(body["id"])
      expect(created.shared_users).to contain_exactly(shared)
    end
  end

  describe "PATCH /api/libraries/:id" do
    it "owner updates and replaces the share set" do
      other = create(:user, email_address: "other@example.com")
      sign_in!(owner)
      patch "/api/libraries/#{library.id}",
        params: {name: "Renamed", shared_user_ids: [other.id]},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(library.reload.name).to eq("Renamed")
      expect(library.shared_users).to contain_exactly(other)
    end

    it "ignores unknown ids and never shares back to the owner" do
      sign_in!(owner)
      patch "/api/libraries/#{library.id}",
        params: {shared_user_ids: [owner.id, 999_999, shared.id]},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(library.reload.shared_users).to contain_exactly(shared)
    end

    it "403 for a shared (non-owner) user" do
      sign_in!(shared)
      patch "/api/libraries/#{library.id}", params: {name: "Nope"}, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(library.reload.name).not_to eq("Nope")
    end

    it "404 for a stranger" do
      sign_in!(stranger)
      patch "/api/libraries/#{library.id}", params: {name: "Nope"}, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/libraries/:id" do
    it "owner deletes, shared gets 403, stranger gets 404" do
      sign_in!(shared)
      delete "/api/libraries/#{library.id}"
      expect(response).to have_http_status(:forbidden)

      sign_in!(stranger)
      delete "/api/libraries/#{library.id}"
      expect(response).to have_http_status(:not_found)

      sign_in!(owner)
      expect { delete "/api/libraries/#{library.id}" }.to change(Library, :count).by(-1)
    end
  end

  describe "books" do
    it "index lists only accessible books" do
      create(:book, library: create(:library, owner: stranger, path: "/mnt/x"), title: "Hidden", file_path: "h.cbz")

      sign_in!(shared)
      get "/api/books"
      titles = response.parsed_body["books"].map { |b| b["title"] }
      expect(titles).to include("InShared")
      expect(titles).not_to include("Hidden")

      sign_in!(stranger)
      get "/api/books"
      expect(response.parsed_body["books"].map { |b| b["title"] }).not_to include("InShared")
    end

    it "show: shared 200, stranger 404" do
      sign_in!(shared)
      get "/api/books/#{book.id}"
      expect(response).to have_http_status(:ok)

      sign_in!(stranger)
      get "/api/books/#{book.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "update/destroy are owner-only (shared 403)" do
      sign_in!(shared)
      patch "/api/books/#{book.id}", params: {title: "Hacked"}, as: :json
      expect(response).to have_http_status(:forbidden)
      delete "/api/books/#{book.id}"
      expect(response).to have_http_status(:forbidden)
      expect(book.reload.title).to eq("InShared")
    end

    it "favorite + progress are allowed for shared (read-only) users" do
      sign_in!(shared)
      post "/api/books/#{book.id}/favorite"
      expect(response).to have_http_status(:created)
      get "/api/books/#{book.id}/progress"
      expect(response).to have_http_status(:ok)
    end

    it "pages 404 for a stranger" do
      sign_in!(stranger)
      get "/api/books/#{book.id}/pages/0"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "scans" do
    it "owner 202, shared 403, stranger 404" do
      sign_in!(owner)
      post "/api/libraries/#{library.id}/scans"
      expect(response).to have_http_status(:accepted)

      sign_in!(shared)
      post "/api/libraries/#{library.id}/scans"
      expect(response).to have_http_status(:forbidden)

      sign_in!(stranger)
      post "/api/libraries/#{library.id}/scans"
      expect(response).to have_http_status(:not_found)
    end
  end
end
