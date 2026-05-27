# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReadingProgress, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:book) }
  end

  describe "validations" do
    it "rejects a negative current_page" do
      progress = ReadingProgress.new(current_page: -1, last_read_at: Time.current)
      expect(progress.valid?).to be false
      expect(progress.errors[:current_page]).to be_present
    end

    it "accepts zero (0-indexed first page)" do
      user = create(:user)
      book = create(:book)
      progress = ReadingProgress.new(user: user, book: book, current_page: 0, last_read_at: Time.current)
      expect(progress).to be_valid
    end
  end

  describe "compound primary key" do
    it "prevents duplicate (user, book) rows" do
      user = create(:user)
      book = create(:book)
      ReadingProgress.create!(user: user, book: book, current_page: 0, last_read_at: Time.current)
      dup = ReadingProgress.new(user: user, book: book, current_page: 5, last_read_at: Time.current)
      # Compound primary key + SQLite raises at the DB layer rather than
      # surfacing as a validation error — that's fine, the controller will
      # use upsert semantics instead.
      expect { dup.save }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#settings" do
    it "round-trips a Hash through the settings_json text column" do
      user = create(:user)
      book = create(:book)
      progress = ReadingProgress.create!(
        user: user, book: book, current_page: 0, last_read_at: Time.current
      )
      progress.settings = {"spread" => true, "direction" => "rtl"}
      progress.save!
      progress.reload
      expect(progress.settings).to eq("spread" => true, "direction" => "rtl")
    end

    it "returns {} when settings_json is blank or invalid" do
      progress = ReadingProgress.new
      expect(progress.settings).to eq({})
      progress.settings_json = "not-json"
      expect(progress.settings).to eq({})
    end
  end

  describe "cascade" do
    it "is removed when the user is destroyed" do
      user = create(:user)
      book = create(:book)
      ReadingProgress.create!(user: user, book: book, current_page: 3, last_read_at: Time.current)
      expect { user.destroy! }.to change(ReadingProgress, :count).by(-1)
    end

    it "is removed when the book is destroyed" do
      user = create(:user)
      book = create(:book)
      ReadingProgress.create!(user: user, book: book, current_page: 3, last_read_at: Time.current)
      expect { book.destroy! }.to change(ReadingProgress, :count).by(-1)
    end
  end
end
