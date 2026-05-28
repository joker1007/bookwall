# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Libraries", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  describe "GET /api/libraries" do
    it_behaves_like "requires authentication", :get, "/api/libraries"

    it "returns paginated libraries when authenticated" do
      sign_in!
      create_list(:library, 3, owner: user)

      get "/api/libraries"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["libraries"].size).to eq(3)
      expect(body["pagination"]).to include("page", "pages", "count")
    end
  end

  describe "POST /api/libraries" do
    it "creates a library" do
      sign_in!

      expect {
        post "/api/libraries",
             params: {name: "Manga", path: "/mnt/books/manga"},
             as: :json
      }.to change(Library, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Manga")
    end

    it "rejects duplicate paths" do
      sign_in!
      create(:library, path: "/mnt/books/dup")

      post "/api/libraries",
           params: {name: "Other", path: "/mnt/books/dup"},
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  describe "GET /api/libraries/:id" do
    it "returns the library" do
      sign_in!
      library = create(:library, owner: user)

      get "/api/libraries/#{library.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(library.id)
    end
  end

  describe "PATCH /api/libraries/:id" do
    it "updates the library" do
      sign_in!
      library = create(:library, name: "Old", owner: user)

      patch "/api/libraries/#{library.id}",
            params: {name: "New"},
            as: :json

      expect(response).to have_http_status(:ok)
      expect(library.reload.name).to eq("New")
    end
  end

  describe "DELETE /api/libraries/:id" do
    it "deletes the library" do
      sign_in!
      library = create(:library, owner: user)

      expect {
        delete "/api/libraries/#{library.id}"
      }.to change(Library, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
