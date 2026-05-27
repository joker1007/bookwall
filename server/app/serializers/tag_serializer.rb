class TagSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |t|
    t.books.size
  end

  attribute :sample_cover_thumb_url do |t|
    CoverUrlHelper.cover_thumb_url(t.first_book)
  end
end
