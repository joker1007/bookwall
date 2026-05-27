# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Preferences", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  describe "GET /api/preferences" do
    it "requires authentication" do
      get "/api/preferences"
      expect(response).to have_http_status(:unauthorized)
    end

    context "when logged in" do
      before do
        post "/api/session",
          params: {email_address: user.email_address, password: password},
          as: :json
      end

      it "returns an empty reader_defaults hash by default" do
        get "/api/preferences"
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["reader_defaults"]).to eq({})
      end

      it "returns the saved reader_defaults from the has_one preference" do
        UserPreference.create!(
          user: user,
          reader_spread: true,
          reader_direction: "rtl",
          reader_scale: "fit_width",
        )

        get "/api/preferences"
        expect(response.parsed_body["reader_defaults"]).to eq(
          "spread" => true,
          "direction" => "rtl",
          "scale" => "fit_width",
        )
      end
    end
  end

  describe "PATCH /api/preferences" do
    before do
      post "/api/session",
        params: {email_address: user.email_address, password: password},
        as: :json
    end

    it "stores a new set of reader defaults" do
      patch "/api/preferences",
        params: {
          reader_defaults: {
            spread: true, direction: "rtl", scale: "fit_height", preload_ahead: 6
          }
        },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reader_defaults"]).to eq(
        "spread" => true,
        "direction" => "rtl",
        "scale" => "fit_height",
        "preload_ahead" => 6,
      )
      expect(user.reload.reader_defaults).to eq(
        "spread" => true,
        "direction" => "rtl",
        "scale" => "fit_height",
        "preload_ahead" => 6,
      )
    end

    it "ignores unknown keys" do
      patch "/api/preferences",
        params: {reader_defaults: {spread: false, malicious: "value"}},
        as: :json

      expect(user.reload.reader_defaults).to eq("spread" => false)
    end
  end
end
