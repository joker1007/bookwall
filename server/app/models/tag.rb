# frozen_string_literal: true

class Tag < ApplicationRecord
  include GlobalMetadata

  has_many :book_tags, dependent: :destroy
  has_many :books, through: :book_tags

  represents_book_metadata join_model: BookTag, foreign_key: :tag_id

  validates :name, presence: true, uniqueness: true

  scope :accessible_by, ->(user) {
    where(id: BookTag.joins(:book)
                     .where(books: {library_id: Library.accessible_by(user).select(:id)})
                     .select(:tag_id))
  }
end
