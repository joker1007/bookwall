require "rails_helper"

RSpec.describe "Api::Registrations", type: :request do
  describe "POST /api/registrations" do
    it "creates a user and starts a session" do
      expect {
        post "/api/registrations",
             params: {
               email_address: "alice@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.cookies["session_id"]).to be_present
      expect(response.parsed_body["email_address"]).to eq("alice@example.com")
    end

    it "returns errors for invalid params" do
      post "/api/registrations",
           params: {email_address: "", password: "x"},
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_an(Array)
    end

    it "returns errors when password is missing" do
      post "/api/registrations",
           params: {email_address: "bob@example.com"},
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
