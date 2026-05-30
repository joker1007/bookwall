# frozen_string_literal: true

class BookSerializer
  include Alba::Resource

  attributes :id, :title, :volume, :file_format, :file_path, :file_size,
             :page_count, :published_at, :added_at, :scanned_at,
             :library_id, :series_id

  attribute :series_name do |b|
    b.series&.name
  end

  attribute :authors do |b|
    b.authors.map { |a| {id: a.id, name: a.name} }
  end

  attribute :tags do |b|
    b.tags.map { |t| {id: t.id, name: t.name} }
  end

  attribute :favorited do |b|
    Array(params[:favorite_book_ids]).include?(b.id)
  end

  attribute :cover do |b|
    next nil unless b.cover.attached?
    helpers = Rails.application.routes.url_helpers
    {
      url: helpers.rails_blob_path(b.cover, only_path: true),
      thumb_url: CoverUrlHelper.cover_thumb_url(b)
    }
  end

  # Reading progress for the signed-in user, batch-preloaded by the
  # controller into params[:reading_progress_by_book_id]. Null when the
  # user has never opened the book, or when the file format doesn't
  # support a precise fraction yet (EPUB — pending a stored
  # fraction column).
  attribute :reading_progress do |b|
    progress = params[:reading_progress_by_book_id]&.fetch(b.id, nil)
    next nil if progress.nil?
    {
      fraction: ReadingProgressFraction.call(b, progress),
      current_page: progress.current_page,
      last_read_at: progress.last_read_at&.iso8601
    }
  end
end
