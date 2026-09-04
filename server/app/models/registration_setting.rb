# frozen_string_literal: true

class RegistrationSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end

  # Sign-up stays open until the first account exists so the initial setup
  # needs no out-of-band step; after that it is opt-in via the setting.
  def self.registration_open?
    !User.exists? || instance.public_registration_enabled
  end
end
