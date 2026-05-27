# frozen_string_literal: true

class AuthorSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |a|
    a.books.size
  end

  attribute :sample_cover_thumb_url do |a|
    CoverUrlHelper.cover_thumb_url(a.first_book)
  end
end
