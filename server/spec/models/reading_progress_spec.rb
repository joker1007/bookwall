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

  describe "scopes" do
    let(:user) { create(:user) }
    let(:lib) { create(:library, owner: user) }
    let(:other_lib) { create(:library, owner: user) }

    def progress_for(book, account: user)
      ReadingProgress.create!(user: account, book: book, current_page: 1, last_read_at: Time.current)
    end

    it ".for_user returns only the given user's rows" do
      book = create(:book, library: lib)
      progress_for(book)
      progress_for(book, account: create(:user))

      result = ReadingProgress.for_user(user)
      expect(result.count).to eq(1)
      expect(result.first.user_id).to eq(user.id)
    end

    it ".in_libraries keeps only rows whose book is in the given libraries" do
      in_book = create(:book, library: lib, file_path: "a.cbz")
      out_book = create(:book, library: other_lib, file_path: "b.cbz")
      progress_for(in_book)
      progress_for(out_book)

      expect(ReadingProgress.in_libraries([lib.id]).pluck(:book_id)).to contain_exactly(in_book.id)
    end

    it ".read returns rows that carry a last_read_at" do
      book = create(:book, library: lib)
      progress_for(book)

      expect(ReadingProgress.read.pluck(:book_id)).to contain_exactly(book.id)
    end
  end

  describe ".by_book_id_for" do
    let(:user) { create(:user) }
    let(:lib) { create(:library, owner: user) }

    it "returns a {book_id => progress} hash for the user's books" do
      book = create(:book, library: lib)
      progress = ReadingProgress.create!(user: user, book: book, current_page: 4, last_read_at: Time.current)

      result = ReadingProgress.by_book_id_for(user, [book.id])
      expect(result.keys).to contain_exactly(book.id)
      expect(result[book.id]).to eq(progress)
    end

    it "scopes to the given user" do
      book = create(:book, library: lib)
      ReadingProgress.create!(user: create(:user), book: book, current_page: 1, last_read_at: Time.current)

      expect(ReadingProgress.by_book_id_for(user, [book.id])).to eq({})
    end

    it "returns {} for an empty input without querying" do
      expect(ReadingProgress.by_book_id_for(user, [])).to eq({})
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
