# frozen_string_literal: true

class Favorite < ApplicationRecord
  self.primary_key = [:user_id, :book_id]

  belongs_to :user
  belongs_to :book

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :in_libraries, ->(library_ids) { joins(:book).where(books: {library_id: library_ids}) }
end
