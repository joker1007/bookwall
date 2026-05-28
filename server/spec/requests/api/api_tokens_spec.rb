# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::ApiTokens", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  describe "POST /api/api_tokens" do
    it "requires authentication" do
      post "/api/api_tokens", params: {name: "reader"}, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "issues a token and returns the plain token only on creation" do
      sign_in!(user)
      post "/api/api_tokens", params: {name: "reader"}, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["token"]).to be_present
      expect(response.parsed_body["name"]).to eq("reader")
    end
  end

  describe "GET /api/api_tokens via Bearer header" do
    it "authenticates using the Bearer token after the session is destroyed" do
      sign_in!(user)
      post "/api/api_tokens", params: {name: "reader"}, as: :json
      plain = response.parsed_body["token"]
      delete "/api/session"

      get "/api/api_tokens", headers: {"Authorization" => "Bearer #{plain}"}
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["name"]).to eq("reader")
    end

    it "rejects an invalid Bearer token" do
      get "/api/api_tokens", headers: {"Authorization" => "Bearer invalid"}
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/api_tokens/:id" do
    it "revokes the token" do
      sign_in!(user)
      post "/api/api_tokens", params: {name: "reader"}, as: :json
      id = response.parsed_body["id"]

      expect {
        delete "/api/api_tokens/#{id}"
      }.to change(ApiToken, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
