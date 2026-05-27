# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to have_secure_password }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to allow_value("alice@example.com").for(:email_address) }
    it { is_expected.not_to allow_value("not-an-email").for(:email_address) }
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:api_tokens).dependent(:destroy) }
  end

  describe "#email_address normalization" do
    it "is downcased and stripped" do
      user = create(:user, email_address: "  Foo@Example.COM ")
      expect(user.email_address).to eq("foo@example.com")
    end
  end
end
