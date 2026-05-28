# frozen_string_literal: true

class SeriesSerializer
  include Alba::Resource
  include TaxonomyAttributes

  attributes :id, :name, :library_id, :created_at, :updated_at

  book_count_attribute
  sample_cover_thumb_attribute
end
