# frozen_string_literal: true

class Favorite < ApplicationRecord
  self.primary_key = [:user_id, :book_id]

  belongs_to :user
  belongs_to :book
end
