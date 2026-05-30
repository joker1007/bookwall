# frozen_string_literal: true

class Series < ApplicationRecord
  self.table_name = "series"

  belongs_to :library
  has_many :books, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :library_id}

  scope :accessible_by, ->(user) { where(library_id: Library.accessible_by(user).select(:id)) }
  scope :in_library, ->(library_id) { where(library_id: library_id) }

  def self.book_counts_for(series, library_ids:)
    Book.where(series_id: series.map(&:id), library_id: library_ids)
      .group(:series_id).count
  end

  def first_book
    books.with_attached_cover
      .order(Arel.sql("CASE WHEN volume IS NULL THEN 1 ELSE 0 END, volume ASC, id ASC"))
      .first
  end
end
