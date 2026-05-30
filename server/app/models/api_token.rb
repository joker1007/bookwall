# frozen_string_literal: true

class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: {maximum: 100}
  validates :token_digest, presence: true, uniqueness: true

  class << self
    def issue!(user:, name:, expires_at: nil)
      plain = SecureRandom.urlsafe_base64(32)
      create!(
        user: user,
        name: name,
        expires_at: expires_at,
        token: plain,
        token_digest: digest_for(plain)
      )
    end

    def authenticate(plain)
      return nil if plain.blank?
      token = find_by(token_digest: digest_for(plain))
      return nil unless token
      return nil if token.expired?

      token.touch_last_used!
      token
    end

    def digest_for(plain)
      Digest::SHA256.hexdigest(plain)
    end
  end

  def plain_token
    token
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
