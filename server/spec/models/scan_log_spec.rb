require "rails_helper"

RSpec.describe ScanLog, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:library) }
  end

  describe "enum status" do
    it { is_expected.to define_enum_for(:status).with_values(ScanLog::STATUSES) }
  end
end
