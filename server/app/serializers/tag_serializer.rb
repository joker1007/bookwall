# frozen_string_literal: true

class TagSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |t|
    counts = params[:book_counts]
    counts ? counts.fetch(t.id, 0) : t.books.size
  end
end
