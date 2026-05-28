# frozen_string_literal: true

require "rails_helper"

RSpec.describe LibraryShare, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:library) }
    it { is_expected.to belong_to(:user) }
  end

  it "uses a composite primary key" do
    expect(LibraryShare.primary_key).to eq(%w[library_id user_id])
  end

  it "is unique per (library, user) pair" do
    library = create(:library)
    user = create(:user)
    create(:library_share, library: library, user: user)
    expect {
      LibraryShare.create!(library: library, user: user)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
