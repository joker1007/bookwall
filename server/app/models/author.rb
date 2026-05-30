# frozen_string_literal: true

class Author < ApplicationRecord
  include GlobalMetadata

  has_many :book_authors, dependent: :destroy
  has_many :books, through: :book_authors

  represents_book_metadata join_model: BookAuthor, foreign_key: :author_id

  validates :name, presence: true, uniqueness: true

  scope :accessible_by, ->(user) {
    where(id: BookAuthor.joins(:book)
                        .where(books: {library_id: Library.accessible_by(user).select(:id)})
                        .select(:author_id))
  }

  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
