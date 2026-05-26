class Library < ApplicationRecord
  has_many :series, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :scan_logs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :path, presence: true, uniqueness: true
end
