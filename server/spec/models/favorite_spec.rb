# frozen_string_literal: true

require "rails_helper"

RSpec.describe Favorite, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:book) }
  end

  it "prevents duplicate favorites for the same user and book" do
    favorite = create(:favorite)
    duplicate = build(:favorite, user: favorite.user, book: favorite.book)
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
