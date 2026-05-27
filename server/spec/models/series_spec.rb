# frozen_string_literal: true

require "rails_helper"

RSpec.describe Series, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:library) }
    it { is_expected.to have_many(:books).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:series) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:library_id) }
  end

  it "allows the same name in different libraries" do
    series_a = create(:series, name: "Same")
    series_b = build(:series, name: "Same", library: create(:library))
    expect(series_b).to be_valid
    expect(series_a).to be_persisted
  end

  describe "#destroy" do
    it "cascades into contained books and their join rows" do
      library = create(:library)
      series = Series.create!(library: library, name: "Cascade Test")
      book = create(:book, library: library, series: series)
      author = Author.create!(name: "Cascade Author")
      tag = Tag.create!(name: "cascade-tag")
      BookAuthor.create!(book: book, author: author)
      BookTag.create!(book: book, tag: tag)

      expect { series.destroy! }
        .to change(Book, :count).by(-1)
        .and change(BookAuthor, :count).by(-1)
        .and change(BookTag, :count).by(-1)

      # Author / Tag rows themselves are shared across the library, so they
      # remain — only the join rows pointing at deleted books go away.
      expect(Author.exists?(author.id)).to be true
      expect(Tag.exists?(tag.id)).to be true
    end

    it "leaves the underlying file on disk untouched" do
      library = create(:library, path: Rails.root.join("spec/fixtures/files").to_s)
      file_path = "#{library.path}/sample.cbz"
      series = Series.create!(library: library, name: "Disk Safety")
      create(:book, library: library, series: series, file_path: file_path)

      expect(File).to exist(file_path)
      series.destroy!
      expect(File).to exist(file_path)
    end
  end
end
