class BookAuthor < ApplicationRecord
  self.primary_key = [:book_id, :author_id]

  belongs_to :book
  belongs_to :author

  after_commit :sync_book_fts

  private

  def sync_book_fts
    Books::FtsIndex.upsert(book)
  end
end
