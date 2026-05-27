# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPreference, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:user_preference) }

    it { is_expected.to validate_inclusion_of(:reader_direction).in_array(%w[ltr rtl]).allow_nil }
    it { is_expected.to validate_inclusion_of(:reader_scale).in_array(%w[fit fit_height fit_width original]).allow_nil }

    it "accepts integer 0..16 for reader_preload_ahead" do
      pref = build(:user_preference, reader_preload_ahead: 0)
      expect(pref).to be_valid
      pref.reader_preload_ahead = 16
      expect(pref).to be_valid
    end

    it "rejects out-of-range reader_preload_ahead" do
      pref = build(:user_preference, reader_preload_ahead: -1)
      expect(pref).to be_invalid
      pref.reader_preload_ahead = 17
      expect(pref).to be_invalid
    end

    it "allows nil reader_preload_ahead (means fall through to client default)" do
      pref = build(:user_preference, reader_preload_ahead: nil)
      expect(pref).to be_valid
    end

    it "accepts integer 50..300 for reader_font_size" do
      expect(build(:user_preference, reader_font_size: 50)).to be_valid
      expect(build(:user_preference, reader_font_size: 300)).to be_valid
    end

    it "rejects out-of-range reader_font_size" do
      expect(build(:user_preference, reader_font_size: 49)).to be_invalid
      expect(build(:user_preference, reader_font_size: 301)).to be_invalid
    end

    it { is_expected.to validate_inclusion_of(:reader_theme).in_array(%w[light dark sepia]).allow_nil }
    it { is_expected.to validate_inclusion_of(:reader_writing_mode).in_array(%w[horizontal vertical]).allow_nil }
  end

  describe "#reader_defaults" do
    let(:user) { create(:user) }

    it "returns only the keys that have a stored value" do
      pref = UserPreference.create!(user: user, reader_spread: true)
      expect(pref.reader_defaults).to eq("spread" => true)
    end

    it "round-trips a full set of reader settings through the writer" do
      pref = UserPreference.new(user: user)
      pref.reader_defaults = {
        spread: false, direction: "rtl", scale: "fit_height", preload_ahead: 6,
        font_size: 130, theme: "dark", writing_mode: "vertical"
      }
      pref.save!
      expect(pref.reload.reader_defaults).to eq(
        "spread" => false,
        "direction" => "rtl",
        "scale" => "fit_height",
        "preload_ahead" => 6,
        "font_size" => 130,
        "theme" => "dark",
        "writing_mode" => "vertical",
      )
    end

    it "only overwrites keys present in the assignment" do
      pref = UserPreference.create!(user: user, reader_spread: true, reader_direction: "ltr")
      pref.reader_defaults = {scale: "original"}
      pref.save!
      expect(pref.reload.reader_defaults).to eq(
        "spread" => true,
        "direction" => "ltr",
        "scale" => "original",
      )
    end
  end

  describe "cascade" do
    it "is destroyed when the owning user is destroyed" do
      user = create(:user)
      UserPreference.create!(user: user, reader_spread: true)
      expect { user.destroy! }.to change(UserPreference, :count).by(-1)
    end
  end
end
