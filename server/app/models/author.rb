# frozen_string_literal: true

class Author < ApplicationRecord
  has_many :book_authors, dependent: :destroy
  has_many :books, through: :book_authors

  validates :name, presence: true, uniqueness: true

  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
