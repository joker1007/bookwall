class Series < ApplicationRecord
  self.table_name = "series"

  belongs_to :library
  has_many :books, dependent: :nullify

  validates :name, presence: true, uniqueness: {scope: :library_id}
end
