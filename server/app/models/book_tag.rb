class BookTag < ApplicationRecord
  self.primary_key = [:book_id, :tag_id]

  belongs_to :book
  belongs_to :tag

  after_commit :sync_book_fts

  private

  def sync_book_fts
    Books::FtsIndex.upsert(book)
  end
end
