require "rails_helper"

RSpec.describe Tag, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:book_tags).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:book_tags) }
  end

  describe "validations" do
    subject { build(:tag) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end
end
