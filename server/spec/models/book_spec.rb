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
    it { is_expected.to validate_uniqueness_of(:file_path) }
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
end
