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

  has_many :reading_progresses, dependent: :destroy

  has_one_attached :cover do |attachable|
    attachable.variant :thumb, resize_to_limit: [240, nil]
    attachable.variant :medium, resize_to_limit: [480, nil]
    attachable.variant :large, resize_to_limit: [960, nil]
  end

  validates :title, presence: true
  validates :file_path, presence: true, uniqueness: {scope: :library_id}
  validates :file_format, presence: true
  validates :file_size, numericality: {greater_than_or_equal_to: 0}

  # The on-disk path resolved against the owning library's root. Stored
  # `file_path` is relative (so libraries can be remounted) and consumers
  # who need to actually open the file go through this method.
  def absolute_path
    return file_path if library.nil?
    File.expand_path(File.join(library.path, file_path))
  end

  before_save :ensure_added_at
  # FTS sync runs out-of-band so the writing transaction (API update etc.)
  # doesn't hold the SQLite writer lock while FTS5 internals rewrite
  # books_fts_data / books_fts_idx / ... The library scanner sets the
  # `:bookwall_skip_fts_callback` thread-local to suppress these per-row
  # callbacks and enqueues one bulk job at the end of the scan instead.
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
