# frozen_string_literal: true

class AuthorSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |a|
    a.books.size
  end

  attribute :sample_cover_thumb_url do |a|
    book = params[:first_books]&.fetch(a.id, nil) || a.first_book
    CoverUrlHelper.cover_thumb_url(book)
  end
end
