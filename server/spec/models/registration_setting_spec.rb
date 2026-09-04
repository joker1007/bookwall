# frozen_string_literal: true

require "rails_helper"

RSpec.describe RegistrationSetting, type: :model do
  describe ".instance" do
    it "creates the singleton row on first access and reuses it after" do
      expect {
        described_class.instance
      }.to change(described_class, :count).by(1)

      expect {
        described_class.instance
      }.not_to change(described_class, :count)
    end

    it "defaults public registration to disabled" do
      expect(described_class.instance.public_registration_enabled).to be(false)
    end
  end

  describe ".registration_open?" do
    it "is open while no user exists" do
      expect(described_class.registration_open?).to be(true)
    end

    it "closes once the first user exists" do
      create(:user)
      expect(described_class.registration_open?).to be(false)
    end

    it "reopens when public registration is enabled" do
      create(:user)
      described_class.instance.update!(public_registration_enabled: true)
      expect(described_class.registration_open?).to be(true)
    end
  end
end
