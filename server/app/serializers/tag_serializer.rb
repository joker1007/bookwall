# frozen_string_literal: true

class TagSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |t|
    t.books.size
  end

  attribute :sample_cover_thumb_url do |t|
    book = params[:first_books]&.fetch(t.id, nil) || t.first_book
    CoverUrlHelper.cover_thumb_url(book)
  end
end
