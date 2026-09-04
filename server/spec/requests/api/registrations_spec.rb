# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Registrations", type: :request do
  describe "POST /api/registrations" do
    def register(email_address: "alice@example.com", password: "password123")
      post "/api/registrations",
           params: {
             email_address: email_address,
             password: password,
             password_confirmation: password
           },
           as: :json
    end

    it "creates the first user and starts a session" do
      expect { register }.to change(User, :count).by(1)

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

    context "once a user exists" do
      before { create(:user) }

      it "rejects further sign-ups by default" do
        expect { register(email_address: "bob@example.com") }.not_to change(User, :count)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq("error" => "registration_closed")
        expect(response.cookies["session_id"]).to be_blank
      end

      it "accepts sign-ups when public registration is enabled" do
        RegistrationSetting.instance.update!(public_registration_enabled: true)

        expect { register(email_address: "bob@example.com") }.to change(User, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end
  end
end
