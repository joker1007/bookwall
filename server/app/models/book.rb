# frozen_string_literal: true

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

  has_many :collection_books, dependent: :destroy
  has_many :collections, through: :collection_books

  has_many :reading_progresses, dependent: :destroy

  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_limit: [240, nil]
  end

  validates :title, presence: true
  validates :file_path, presence: true, uniqueness: {scope: :library_id}
  validates :file_format, presence: true
  validates :file_size, numericality: {greater_than_or_equal_to: 0}

  scope :accessible_by, ->(user) { where(library_id: Library.accessible_by(user).select(:id)) }
  # Canonical order for volumes within a series. Shared by #next_in_series and the
  # OPDS series feed so the reader's "next volume" matches the feed order exactly.
  scope :in_series_order, -> { order(:volume, :title) }

  def absolute_path
    return file_path if library.nil?
    File.expand_path(File.join(library.path, file_path))
  end

  def replace_authors(names)
    self.authors = Author.upsert_by_name(names)
  end

  def replace_tags(names)
    self.tags = Tag.upsert_by_name(names)
  end

  def next_in_series(scope = self.class.all)
    return nil unless series_id
    ordered_ids = scope.where(series_id: series_id).in_series_order.pluck(:id)
    position = ordered_ids.index(id)
    return nil if position.nil?
    next_id = ordered_ids[position + 1]
    next_id && scope.find_by(id: next_id)
  end

  before_save :ensure_added_at
  # Sync FTS out-of-band to avoid holding the SQLite writer lock during FTS5 rewrites;
  # the scanner sets :bookwall_skip_fts_callback and bulk-enqueues once at the end.
  after_commit :enqueue_fts_sync, on: %i[create update], unless: :fts_callback_skipped?
  after_commit :enqueue_fts_delete, on: :destroy, unless: :fts_callback_skipped?

  private

  def ensure_added_at
    self.added_at ||= Time.current
  end

  def fts_callback_skipped?
    Thread.current[:bookwall_skip_fts_callback]
  end

  def enqueue_fts_sync
    Books::FtsSyncJob.perform_later([id], "upsert")
  end

  def enqueue_fts_delete
    Books::FtsSyncJob.perform_later([id], "delete")
  end
end
