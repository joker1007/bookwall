# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduledTaskSetting, type: :model do
  describe ".instance" do
    it "creates the singleton row on first access and reuses it after" do
      expect {
        described_class.instance
      }.to change(described_class, :count).by(1)

      expect {
        described_class.instance
      }.not_to change(described_class, :count)
    end

    it "defaults both switches to enabled" do
      setting = described_class.instance
      expect(setting.daily_scan_enabled).to be(true)
      expect(setting.cleanup_enabled).to be(true)
    end
  end
end
