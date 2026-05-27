class Series < ApplicationRecord
  self.table_name = "series"

  belongs_to :library
  # Deleting a series wipes the books that belong to it. Bookwall only stores
  # metadata, so the destroy cascade clears BookAuthor / BookTag / Favorite
  # joins, the Active Storage cover, and the FTS index — the underlying files
  # on disk are never touched.
  has_many :books, dependent: :destroy

  validates :name, presence: true, uniqueness: {scope: :library_id}

  # Earliest volume (NULL volumes sort last) — used as the thumbnail for the
  # series in list views.
  def first_book
    books.with_attached_cover
      .order(Arel.sql("CASE WHEN volume IS NULL THEN 1 ELSE 0 END, volume ASC, id ASC"))
      .first
  end
end
