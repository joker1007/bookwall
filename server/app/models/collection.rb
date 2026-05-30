# frozen_string_literal: true

# User-private grouping; any accessible book (including shared read-only ones) may be collected.
class Collection < ApplicationRecord
  belongs_to :user

  has_many :collection_books, dependent: :destroy
  has_many :books, through: :collection_books

  validates :name, presence: true, uniqueness: {scope: :user_id}

  scope :for_user, ->(user) { where(user_id: user.id) }

  def self.book_counts_for(collections, library_ids:)
    CollectionBook.joins(:book)
      .where(collection_id: collections.map(&:id), books: {library_id: library_ids})
      .group(:collection_id).count
  end

  def add_books(books)
    rows = books.map { |book| {collection_id: id, book_id: book.id, created_at: Time.current} }
    return if rows.empty?
    CollectionBook.upsert_all(rows, unique_by: %i[collection_id book_id])
  end

  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
