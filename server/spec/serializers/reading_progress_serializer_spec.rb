# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReadingProgressSerializer do
  let(:library) { create(:library) }
  let(:book) { create(:book, library: library, page_count: 20) }
  let(:user) { create(:user) }

  def serialize(record)
    described_class.new(record).serializable_hash
  end

  it "exposes the stored progress attributes" do
    progress = ReadingProgress.create!(
      user: user, book: book, current_page: 7,
      last_read_at: Time.utc(2026, 5, 29, 12), epub_cfi: "epubcfi(/6/4)",
      progress_fraction: 0.35
    )

    hash = serialize(progress)
    expect(hash["current_page"]).to eq(7)
    expect(hash["epub_cfi"]).to eq("epubcfi(/6/4)")
    expect(hash["progress_fraction"]).to eq(0.35)
    expect(hash["last_read_at"]).to be_present
  end

  it "parses settings from the stored JSON" do
    progress = ReadingProgress.new(
      user: user, book: book, current_page: 0,
      settings_json: '{"spread":true,"direction":"rtl"}'
    )

    expect(serialize(progress)["settings"]).to eq("spread" => true, "direction" => "rtl")
  end

  it "returns an empty settings hash when none is stored" do
    progress = ReadingProgress.new(user: user, book: book, current_page: 0)
    expect(serialize(progress)["settings"]).to eq({})
  end
end
