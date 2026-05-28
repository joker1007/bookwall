# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session do
  let(:user) { create(:user) }

  it "belongs to a user" do
    session = Session.new
    expect(session).not_to be_valid
    expect(session.errors[:user]).to be_present
  end

  it "stores the user agent and ip address captured at login" do
    session = user.sessions.create!(user_agent: "RSpec/1.0", ip_address: "10.0.0.1")
    expect(session.reload.user_agent).to eq("RSpec/1.0")
    expect(session.ip_address).to eq("10.0.0.1")
  end

  it "is destroyed when its user is destroyed" do
    session = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")
    expect { user.destroy }.to change { Session.exists?(session.id) }.from(true).to(false)
  end
end
