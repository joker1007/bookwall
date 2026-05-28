# frozen_string_literal: true

class Library < ApplicationRecord
  belongs_to :owner, class_name: "User"

  has_many :series, dependent: :destroy
  has_many :books, dependent: :destroy
  has_many :scan_logs, dependent: :destroy

  has_many :library_shares, dependent: :destroy
  has_many :shared_users, through: :library_shares, source: :user

  validates :name, presence: true, uniqueness: true
  validates :path, presence: true, uniqueness: true

  scope :owned_by, ->(user) { where(owner_id: user.id) }

  # The canonical visibility scope: libraries the user owns OR has been
  # shared. Everything browsable (Book/Series/Tag/Author) is derived from
  # the set of accessible library ids this produces.
  scope :accessible_by, ->(user) {
    left_joins(:library_shares)
      .where("libraries.owner_id = :uid OR library_shares.user_id = :uid", uid: user.id)
      .distinct
  }

  def can_manage?(user)
    owner_id == user.id
  end
end
