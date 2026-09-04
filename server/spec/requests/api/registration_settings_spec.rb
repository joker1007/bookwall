# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::RegistrationSettings", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/registration_settings" do
    it "is readable without authentication and reports registration open before the first user" do
      get "/api/registration_settings"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "public_registration_enabled" => false,
        "registration_open" => true
      )
    end

    it "reports registration closed once a user exists" do
      user

      get "/api/registration_settings"

      expect(response.parsed_body).to eq(
        "public_registration_enabled" => false,
        "registration_open" => false
      )
    end
  end

  describe "PATCH /api/registration_settings" do
    it_behaves_like "requires authentication", :patch, "/api/registration_settings"

    it "toggles public registration" do
      sign_in!

      patch "/api/registration_settings",
        params: {public_registration_enabled: true},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "public_registration_enabled" => true,
        "registration_open" => true
      )
      expect(RegistrationSetting.instance.public_registration_enabled).to be(true)
    end
  end
end
