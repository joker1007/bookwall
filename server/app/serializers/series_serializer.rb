class SeriesSerializer
  include Alba::Resource

  attributes :id, :name, :library_id, :created_at, :updated_at

  attribute :book_count do |s|
    s.books.size
  end

  attribute :sample_cover_thumb_url do |s|
    CoverUrlHelper.cover_thumb_url(s.first_book)
  end
end
