# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::FirstBookPreloader do
  let(:library) { create(:library) }

  def attach_cover(book)
    book.cover.attach(
      io: StringIO.new("fake-jpg-bytes"),
      filename: "c.jpg",
      content_type: "image/jpeg"
    )
  end

  describe ".for_series" do
    it "returns the earliest-volume book per series" do
      s1 = Series.create!(library: library, name: "S1")
      s2 = Series.create!(library: library, name: "S2")
      s1_vol2 = create(:book, library: library, series: s1, title: "V2", volume: 2,
        added_at: 2.days.ago, file_path: "s1-v2.cbz")
      _s1_vol1 = create(:book, library: library, series: s1, title: "V1", volume: 1,
        added_at: 1.day.ago, file_path: "s1-v1.cbz")
      s2_only = create(:book, library: library, series: s2, title: "Only", volume: 1,
        file_path: "s2.cbz")
      attach_cover(s1_vol2)
      attach_cover(s2_only)

      result = described_class.for_series([s1, s2])

      expect(result[s1.id].title).to eq("V1")
      expect(result[s2.id].title).to eq("Only")
    end

    it "returns an empty hash for an empty input" do
      expect(described_class.for_series([])).to eq({})
    end

    it "does not fire one cover-preload query per row" do
      # Build five series, each with one book + cover, and verify the
      # whole batch resolves in a fixed handful of queries.
      records = 5.times.map do |i|
        series = Series.create!(library: library, name: "S#{i}")
        book = create(:book, library: library, series: series,
          title: "B#{i}", volume: 1, file_path: "b#{i}.cbz")
        attach_cover(book)
        series
      end

      query_count = 0
      callback = lambda do |_n, _start, _finish, _id, payload|
        next if /SCHEMA|TRANSACTION|SAVEPOINT|RELEASE/.match?(payload[:sql])
        query_count += 1
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.for_series(records).each_value(&:cover)
      end

      # 1 query to find the first-book ids, 1 query for books, then a
      # small fixed number for the AS preload chain (attachments,
      # blobs, variant_records). Comfortably under 10, regardless of N.
      expect(query_count).to be < 10
    end
  end

  describe ".for_authors" do
    it "returns the earliest-added book per author" do
      a1 = Author.create!(name: "Alice")
      a2 = Author.create!(name: "Bob")
      early = create(:book, library: library, title: "Early",
        added_at: 3.days.ago, file_path: "early.cbz")
      late = create(:book, library: library, title: "Late",
        added_at: 1.day.ago, file_path: "late.cbz")
      early.authors << a1
      late.authors << a1
      late.authors << a2

      result = described_class.for_authors([a1, a2])

      expect(result[a1.id].title).to eq("Early")
      expect(result[a2.id].title).to eq("Late")
    end
  end

  describe ".for_collections" do
    it "returns the earliest-added book per collection" do
      c1 = create(:collection)
      c2 = create(:collection)
      early = create(:book, library: library, title: "Early",
        added_at: 3.days.ago, file_path: "early.cbz")
      late = create(:book, library: library, title: "Late",
        added_at: 1.day.ago, file_path: "late.cbz")
      c1.books << [early, late]
      c2.books << late

      result = described_class.for_collections([c1, c2])

      expect(result[c1.id].title).to eq("Early")
      expect(result[c2.id].title).to eq("Late")
    end
  end
end
