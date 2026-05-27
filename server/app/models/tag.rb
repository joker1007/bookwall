class Tag < ApplicationRecord
  has_many :book_tags, dependent: :destroy
  has_many :books, through: :book_tags

  validates :name, presence: true, uniqueness: true

  def first_book
    books.with_attached_cover.order(:added_at, :id).first
  end
end
