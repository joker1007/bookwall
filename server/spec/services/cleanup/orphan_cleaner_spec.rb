# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cleanup::OrphanCleaner do
  let(:tmpdir) { Dir.mktmpdir("bookwall-cleanup-") }
  let(:library) { create(:library, path: tmpdir) }

  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  def book_with_file(name, **attrs)
    FileUtils.touch(File.join(tmpdir, name))
    create(:book, library: library, file_path: name, **attrs)
  end

  describe "#call" do
    it "destroys books whose files are gone and keeps the ones still present" do
      present = book_with_file("present.cbz")
      missing = create(:book, library: library, file_path: "gone.cbz")

      result = described_class.new.call

      expect(Book.exists?(present.id)).to be(true)
      expect(Book.exists?(missing.id)).to be(false)
      expect(result.removed_books).to eq(1)
    end

    it "skips a library whose root directory is unavailable (unmounted drive)" do
      offline = create(:library, path: File.join(tmpdir, "unmounted"))
      book = create(:book, library: offline, file_path: "anything.cbz")

      described_class.new.call

      expect(Book.exists?(book.id)).to be(true)
    end

    it "removes tags left with no books and keeps tags still in use" do
      kept_book = book_with_file("kept.cbz")
      used_tag = create(:tag)
      kept_book.tags << used_tag
      orphan_tag = create(:tag)

      result = described_class.new.call

      expect(Tag.exists?(used_tag.id)).to be(true)
      expect(Tag.exists?(orphan_tag.id)).to be(false)
      expect(result.removed_tags).to eq(1)
    end

    it "removes authors left with no books and keeps authors still in use" do
      kept_book = book_with_file("kept.cbz")
      used_author = create(:author)
      kept_book.authors << used_author
      orphan_author = create(:author)

      result = described_class.new.call

      expect(Author.exists?(used_author.id)).to be(true)
      expect(Author.exists?(orphan_author.id)).to be(false)
      expect(result.removed_authors).to eq(1)
    end

    it "sweeps up tags/authors orphaned by the book deletion in the same run" do
      missing = create(:book, library: library, file_path: "gone.cbz")
      tag = create(:tag)
      author = create(:author)
      missing.tags << tag
      missing.authors << author

      described_class.new.call

      expect(Book.exists?(missing.id)).to be(false)
      expect(Tag.exists?(tag.id)).to be(false)
      expect(Author.exists?(author.id)).to be(false)
    end
  end
end
