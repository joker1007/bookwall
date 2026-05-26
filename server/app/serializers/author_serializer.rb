class AuthorSerializer
  include Alba::Resource

  attributes :id, :name, :created_at, :updated_at

  attribute :book_count do |a|
    a.books.size
  end
end
