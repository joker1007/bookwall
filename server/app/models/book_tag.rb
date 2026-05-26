class BookTag < ApplicationRecord
  self.primary_key = [:book_id, :tag_id]

  belongs_to :book
  belongs_to :tag
end
