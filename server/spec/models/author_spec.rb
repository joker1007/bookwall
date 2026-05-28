# frozen_string_literal: true

require "rails_helper"

RSpec.describe Author, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:book_authors).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:book_authors) }
  end

  describe "validations" do
    subject { build(:author) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe ".book_counts_for" do
    it "counts books per author, restricted to the given libraries" do
      lib = create(:library)
      other = create(:library)
      a1 = create(:author)
      a2 = create(:author)
      create(:book, library: lib, file_path: "1.cbz").authors << a1
      create(:book, library: lib, file_path: "2.cbz").authors << [a1, a2]
      create(:book, library: other, file_path: "3.cbz").authors << a1

      counts = Author.book_counts_for([a1, a2], library_ids: [lib.id])

      # a1 has 2 books in lib (the lib book in `other` is excluded), a2 has 1.
      expect(counts).to eq(a1.id => 2, a2.id => 1)
    end
  end

  describe "#manageable_via?" do
    let(:lib) { create(:library) }
    let(:other) { create(:library) }
    let(:author) { create(:author) }

    it "is true when the author has a book in one of the libraries" do
      create(:book, library: lib, file_path: "x.cbz").authors << author
      expect(author.manageable_via?([lib.id])).to be(true)
    end

    it "is false when the author's books are all outside the libraries" do
      create(:book, library: other, file_path: "x.cbz").authors << author
      expect(author.manageable_via?([lib.id])).to be(false)
    end
  end
end
