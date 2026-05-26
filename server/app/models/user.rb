class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorite_books, through: :favorites, source: :book

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: true,
            format: {with: URI::MailTo::EMAIL_REGEXP}
end
