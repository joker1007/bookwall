# frozen_string_literal: true

class SeriesSerializer
  include Alba::Resource

  attributes :id, :name, :library_id, :created_at, :updated_at

  attribute :book_count do |s|
    s.books.size
  end

  attribute :sample_cover_thumb_url do |s|
    # Index endpoints batch-preload the first book per series into
    # params[:first_books] so we don't trigger one cover lookup per
    # row. Falls back to s.first_book for #show, which is one record.
    book = params[:first_books]&.fetch(s.id, nil) || s.first_book
    CoverUrlHelper.cover_thumb_url(book)
  end
end
