class BookAuthor < ApplicationRecord
  self.primary_key = [:book_id, :author_id]

  belongs_to :book
  belongs_to :author
end
