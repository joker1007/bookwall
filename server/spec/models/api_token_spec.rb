require "rails_helper"

RSpec.describe ApiToken, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    subject { build(:api_token) }

    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".issue!" do
    it "creates a token, exposes a plain_token, and stores only its digest" do
      token = ApiToken.issue!(user: user, name: "reader")

      expect(token).to be_persisted
      expect(token.plain_token).to be_present
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(token.plain_token))
    end
  end

  describe ".authenticate" do
    it "returns the token when the plain matches" do
      token = ApiToken.issue!(user: user, name: "reader")
      expect(ApiToken.authenticate(token.plain_token)).to eq(token)
    end

    it "returns nil for an unknown plain" do
      expect(ApiToken.authenticate("nope")).to be_nil
    end

    it "returns nil for a blank plain" do
      expect(ApiToken.authenticate("")).to be_nil
      expect(ApiToken.authenticate(nil)).to be_nil
    end

    it "returns nil for an expired token" do
      token = ApiToken.issue!(user: user, name: "reader", expires_at: 1.hour.ago)
      expect(ApiToken.authenticate(token.plain_token)).to be_nil
    end

    it "updates last_used_at on success" do
      token = ApiToken.issue!(user: user, name: "reader")
      expect {
        ApiToken.authenticate(token.plain_token)
      }.to change { token.reload.last_used_at }.from(nil)
    end
  end
end
