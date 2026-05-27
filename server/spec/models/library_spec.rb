# frozen_string_literal: true

require "rails_helper"

RSpec.describe Library, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:series).dependent(:destroy) }
    it { is_expected.to have_many(:books).dependent(:destroy) }
    it { is_expected.to have_many(:scan_logs).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:library) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_uniqueness_of(:path) }
  end
end
