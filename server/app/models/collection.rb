# frozen_string_literal: true

# A user-private, named grouping of books. Unlike Favorite (a single flat
# set) a user can have many collections; unlike Tag/Series the membership is
# not shared with other users. Adding a book never mutates the book or its
# library, so any *accessible* book (including shared, read-only ones) may be
# collected.
class Collection < ApplicationRecord
  belongs_to :user

  has_many :collection_books, dependent: :destroy
  has_many :books, through: :collection_books

  validates :name, presence: true, uniqueness: {scope: :user_id}

  scope :for_user, ->(user) { where(user_id: user.id) }

  # {collection_id => book_count} for the given collections, counting only
  # books in the supplied (already access-scoped) library ids.
  def self.book_counts_for(collections, library_ids:)
    CollectionBook.joins(:book)
      .where(collection_id: collections.map(&:id), books: {library_id: library_ids})
      .group(:collection_id).count
  end

  # Idempotently add the given books to the collection (duplicates are no-ops
  # thanks to the composite primary key).
  def add_books(books)
    rows = books.map { |book| {collection_id: id, book_id: book.id, created_at: Time.current} }
    return if rows.empty?
    CollectionBook.upsert_all(rows, unique_by: %i[collection_id book_id])
  end

  # Earliest-added book, used as the collection's thumbnail in list views.
  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
