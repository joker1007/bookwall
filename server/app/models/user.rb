# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_books, through: :favorites, source: :book
  has_many :reading_progresses, dependent: :destroy
  has_many :collections, dependent: :destroy

  has_many :owned_libraries, class_name: "Library", foreign_key: :owner_id, dependent: :destroy
  has_many :library_shares, dependent: :destroy
  has_many :shared_libraries, through: :library_shares, source: :library

  # Libraries this user owns or has been shared (the visibility set).
  def accessible_libraries
    Library.accessible_by(self)
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: true,
            format: {with: URI::MailTo::EMAIL_REGEXP}

  has_one :preference, class_name: "UserPreference", dependent: :destroy

  # Convenience helper: returns the persisted reader defaults Hash, or {}
  # when no preference row exists yet.
  def reader_defaults
    preference&.reader_defaults || {}
  end
end
