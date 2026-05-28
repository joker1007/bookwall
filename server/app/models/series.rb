# frozen_string_literal: true

class Series < ApplicationRecord
  self.table_name = "series"

  belongs_to :library
  # Deleting a series wipes the books that belong to it. Bookwall only stores
  # metadata, so the destroy cascade clears BookAuthor / BookTag / Favorite
  # joins, the Active Storage cover, and the FTS index — the underlying files
  # on disk are never touched.
  has_many :books, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :library_id}

  # Series belong to a library directly, so visibility is the library scope.
  scope :accessible_by, ->(user) { where(library_id: Library.accessible_by(user).select(:id)) }
  scope :in_library, ->(library_id) { where(library_id: library_id) }

  # {series_id => book_count} for the given series, counting only books in the
  # supplied (already access-scoped) library ids. Series own their books
  # directly (no join table), so this counts on books.series_id.
  def self.book_counts_for(series, library_ids:)
    Book.where(series_id: series.map(&:id), library_id: library_ids)
      .group(:series_id).count
  end

  # Earliest volume (NULL volumes sort last) — used as the thumbnail for the
  # series in list views.
  def first_book
    books.with_attached_cover
      .order(Arel.sql("CASE WHEN volume IS NULL THEN 1 ELSE 0 END, volume ASC, id ASC"))
      .first
  end
end
