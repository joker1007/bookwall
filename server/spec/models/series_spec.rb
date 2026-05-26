require "rails_helper"

RSpec.describe Series, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:library) }
    it { is_expected.to have_many(:books).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:series) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:library_id) }
  end

  it "allows the same name in different libraries" do
    series_a = create(:series, name: "Same")
    series_b = build(:series, name: "Same", library: create(:library))
    expect(series_b).to be_valid
    expect(series_a).to be_persisted
  end
end
