# frozen_string_literal: true

class LibraryShare < ApplicationRecord
  self.primary_key = [:library_id, :user_id]

  belongs_to :library
  belongs_to :user
end
