# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::ScheduledTaskSettings", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  describe "GET /api/scheduled_task_settings" do
    it_behaves_like "requires authentication", :get, "/api/scheduled_task_settings"

    it "returns both switches defaulting to enabled" do
      sign_in!

      get "/api/scheduled_task_settings"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "daily_scan_enabled" => true,
        "cleanup_enabled" => true
      )
    end
  end

  describe "PATCH /api/scheduled_task_settings" do
    it "toggles the switches" do
      sign_in!

      patch "/api/scheduled_task_settings",
        params: {daily_scan_enabled: false, cleanup_enabled: false},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "daily_scan_enabled" => false,
        "cleanup_enabled" => false
      )
      expect(ScheduledTaskSetting.instance.daily_scan_enabled).to be(false)
      expect(ScheduledTaskSetting.instance.cleanup_enabled).to be(false)
    end
  end
end
