# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :book_tags, dependent: :destroy
  has_many :books, through: :book_tags

  validates :name, presence: true, uniqueness: true

  # Tags are global; only surface those carrying at least one accessible book.
  scope :accessible_by, ->(user) {
    where(id: BookTag.joins(:book)
                     .where(books: {library_id: Library.accessible_by(user).select(:id)})
                     .select(:tag_id))
  }

  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
