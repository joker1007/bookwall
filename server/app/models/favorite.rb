# frozen_string_literal: true

class Favorite < ApplicationRecord
  self.primary_key = [:user_id, :book_id]

  belongs_to :user
  belongs_to :book

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :in_libraries, ->(library_ids) { joins(:book).where(books: {library_id: library_ids}) }

  def self.book_ids_for(user, book_ids)
    return [] if book_ids.empty?
    for_user(user).where(book_id: book_ids).pluck(:book_id)
  end
end
