# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:library) }
    it { is_expected.to belong_to(:series).optional }
    it { is_expected.to have_many(:authors).through(:book_authors) }
    it { is_expected.to have_many(:tags).through(:book_tags) }
    it { is_expected.to have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:book) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_uniqueness_of(:file_path).scoped_to(:library_id) }
  end

  describe "enum file_format" do
    it { is_expected.to define_enum_for(:file_format).with_values(Book::FILE_FORMATS) }
  end

  describe "#added_at" do
    it "is set automatically on create" do
      book = build(:book, added_at: nil)
      book.save!
      expect(book.added_at).to be_present
    end
  end

  describe "#replace_authors / #replace_tags" do
    let(:book) { create(:book) }

    it "creates missing authors and assigns them" do
      expect { book.replace_authors(["Alice", "Bob"]) }.to change(Author, :count).by(2)
      expect(book.authors.pluck(:name)).to contain_exactly("Alice", "Bob")
    end

    it "reuses an existing author instead of duplicating it" do
      create(:author, name: "Alice")
      expect { book.replace_authors(["Alice"]) }.not_to change(Author, :count)
      expect(book.authors.pluck(:name)).to contain_exactly("Alice")
    end

    it "normalizes whitespace, blanks, and duplicates" do
      book.replace_tags(["  fantasy ", "fantasy", "", "  ", "manga"])
      expect(book.tags.pluck(:name)).to contain_exactly("fantasy", "manga")
    end

    it "clears the association when given an empty list" do
      book.replace_authors(["Alice"])
      expect { book.replace_authors([]) }.to change { book.authors.count }.from(1).to(0)
    end
  end

  describe "FTS sync via job" do
    include ActiveJob::TestHelper

    around do |example|
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    it "enqueues an upsert job after create / update" do
      expect {
        create(:book)
      }.to have_enqueued_job(Books::FtsSyncJob).with(
        ->(arg) { arg.is_a?(Array) && arg.size == 1 && arg.first.is_a?(Integer) },
        "upsert",
      )
    end

    it "enqueues a delete job after destroy" do
      book = create(:book)
      clear_enqueued_jobs

      expect {
        book.destroy!
      }.to have_enqueued_job(Books::FtsSyncJob).with([book.id], "delete")
    end

    it "skips the callback while Thread.current[:bookwall_skip_fts_callback] is set (scanner path)" do
      Thread.current[:bookwall_skip_fts_callback] = true
      expect {
        create(:book)
      }.not_to have_enqueued_job(Books::FtsSyncJob)
    ensure
      Thread.current[:bookwall_skip_fts_callback] = nil
    end
  end
end
