# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Sessions", type: :request do
  let(:password) { "password123" }
  let!(:user) { create(:user, email_address: "alice@example.com", password: password) }

  describe "POST /api/session" do
    it "logs in with valid credentials" do
      post "/api/session",
           params: {email_address: "alice@example.com", password: password},
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["email_address"]).to eq("alice@example.com")
      expect(response.cookies["session_id"]).to be_present
    end

    it "rejects invalid credentials" do
      post "/api/session",
           params: {email_address: "alice@example.com", password: "wrong"},
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/session" do
    it "returns 401 without authentication" do
      get "/api/session"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user with a valid cookie session" do
      post "/api/session",
           params: {email_address: user.email_address, password: password},
           as: :json
      get "/api/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email_address"]).to eq(user.email_address)
    end
  end

  describe "DELETE /api/session" do
    it "terminates the session" do
      post "/api/session",
           params: {email_address: user.email_address, password: password},
           as: :json
      expect {
        delete "/api/session"
      }.to change(Session, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
