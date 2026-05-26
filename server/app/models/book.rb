class Book < ApplicationRecord
  FILE_FORMATS = {cbz: 0, epub: 1, pdf: 2, image_dir: 3}.freeze

  enum :file_format, FILE_FORMATS

  belongs_to :library
  belongs_to :series, optional: true

  has_many :book_authors, dependent: :destroy
  has_many :authors, through: :book_authors

  has_many :book_tags, dependent: :destroy
  has_many :tags, through: :book_tags

  has_many :favorites, dependent: :destroy
  has_many :favoriting_users, through: :favorites, source: :user

  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_limit: [240, nil]
    attachable.variant :medium, resize_to_limit: [480, nil]
    attachable.variant :large, resize_to_limit: [960, nil]
  end

  validates :title, presence: true
  validates :file_path, presence: true, uniqueness: true
  validates :file_format, presence: true
  validates :file_size, numericality: {greater_than_or_equal_to: 0}
  validates :file_hash, length: {is: 64}, allow_nil: true

  before_save :ensure_added_at
  after_commit :sync_fts_index, on: %i[create update]
  after_commit :delete_fts_index, on: :destroy

  private

  def ensure_added_at
    self.added_at ||= Time.current
  end

  def sync_fts_index
    Books::FtsIndex.upsert(self)
  end

  def delete_fts_index
    Books::FtsIndex.delete(id)
  end
end
