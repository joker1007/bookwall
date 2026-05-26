require "rails_helper"

RSpec.describe Author, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:book_authors).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:book_authors) }
  end

  describe "validations" do
    subject { build(:author) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end
end
