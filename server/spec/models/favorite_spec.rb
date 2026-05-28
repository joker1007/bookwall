# frozen_string_literal: true

require "rails_helper"

RSpec.describe Favorite, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:book) }
  end

  it "prevents duplicate favorites for the same user and book" do
    favorite = create(:favorite)
    duplicate = build(:favorite, user: favorite.user, book: favorite.book)
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:lib) { create(:library, owner: user) }
    let(:other_lib) { create(:library, owner: user) }

    it ".for_user returns only the given user's favorites" do
      book = create(:book, library: lib)
      create(:favorite, user: user, book: book)
      create(:favorite, user: create(:user), book: book)

      result = Favorite.for_user(user)
      expect(result.count).to eq(1)
      expect(result.first.user_id).to eq(user.id)
    end

    it ".in_libraries keeps only favorites whose book is in the given libraries" do
      in_book = create(:book, library: lib, file_path: "a.cbz")
      out_book = create(:book, library: other_lib, file_path: "b.cbz")
      create(:favorite, user: user, book: in_book)
      create(:favorite, user: user, book: out_book)

      expect(Favorite.in_libraries([lib.id]).pluck(:book_id)).to contain_exactly(in_book.id)
    end
  end
end
