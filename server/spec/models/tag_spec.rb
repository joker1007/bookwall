# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tag, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:book_tags).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:book_tags) }
  end

  describe "validations" do
    subject { build(:tag) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe ".book_counts_for" do
    it "counts books per tag, restricted to the given libraries" do
      lib = create(:library)
      other = create(:library)
      t1 = create(:tag)
      t2 = create(:tag)
      create(:book, library: lib, file_path: "1.cbz").tags << t1
      create(:book, library: lib, file_path: "2.cbz").tags << [t1, t2]
      create(:book, library: other, file_path: "3.cbz").tags << t1

      counts = Tag.book_counts_for([t1, t2], library_ids: [lib.id])

      expect(counts).to eq(t1.id => 2, t2.id => 1)
    end
  end

  describe "#manageable_via?" do
    let(:lib) { create(:library) }
    let(:other) { create(:library) }
    let(:tag) { create(:tag) }

    it "is true when the tag has a book in one of the libraries" do
      create(:book, library: lib, file_path: "x.cbz").tags << tag
      expect(tag.manageable_via?([lib.id])).to be(true)
    end

    it "is false when the tag's books are all outside the libraries" do
      create(:book, library: other, file_path: "x.cbz").tags << tag
      expect(tag.manageable_via?([lib.id])).to be(false)
    end
  end
end
