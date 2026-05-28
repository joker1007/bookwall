# frozen_string_literal: true

class CollectionBook < ApplicationRecord
  self.primary_key = %i[collection_id book_id]

  belongs_to :collection
  belongs_to :book
end
