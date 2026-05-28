# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collection, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:collection_books).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:collection_books) }
  end

  describe "validations" do
    subject { build(:collection) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  it "allows the same name for different users" do
    create(:collection, name: "Reading list", user: create(:user))
    other = build(:collection, name: "Reading list", user: create(:user))
    expect(other).to be_valid
  end

  describe ".book_counts_for" do
    it "counts books per collection, restricted to the given libraries" do
      lib = create(:library)
      other = create(:library)
      c1 = create(:collection)
      c2 = create(:collection)
      a = create(:book, library: lib, file_path: "a.cbz")
      b = create(:book, library: lib, file_path: "b.cbz")
      outside = create(:book, library: other, file_path: "c.cbz")
      c1.books << [a, b, outside]
      c2.books << a

      counts = Collection.book_counts_for([c1, c2], library_ids: [lib.id])

      # c1 has 2 books in lib (the `other`-library book is excluded), c2 has 1.
      expect(counts).to eq(c1.id => 2, c2.id => 1)
    end
  end

  describe "#add_books" do
    let(:collection) { create(:collection) }
    let(:library) { create(:library) }

    it "adds the given books" do
      books = [create(:book, library: library, file_path: "a.cbz"),
        create(:book, library: library, file_path: "b.cbz")]
      collection.add_books(books)
      expect(collection.reload.books).to match_array(books)
    end

    it "is idempotent — re-adding the same book does not duplicate or raise" do
      book = create(:book, library: library, file_path: "a.cbz")
      collection.add_books([book])
      expect { collection.add_books([book]) }.not_to change { collection.reload.books.count }.from(1)
    end

    it "no-ops on an empty list" do
      expect { collection.add_books([]) }.not_to change(CollectionBook, :count)
    end
  end

  describe "cascade" do
    it "is destroyed (with its join rows) when the user is destroyed" do
      user = create(:user)
      collection = create(:collection, user: user)
      collection.books << create(:book)

      expect { user.destroy! }
        .to change(Collection, :count).by(-1)
        .and change(CollectionBook, :count).by(-1)
    end

    it "leaves the books themselves intact when destroyed" do
      collection = create(:collection)
      book = create(:book)
      collection.books << book

      expect { collection.destroy! }.not_to change(Book, :count)
    end
  end
end
