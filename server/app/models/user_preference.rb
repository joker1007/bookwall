# frozen_string_literal: true

class UserPreference < ApplicationRecord
  belongs_to :user

  validates :reader_direction, inclusion: {in: %w[ltr rtl], allow_nil: true}
  validates :reader_scale,
    inclusion: {in: %w[fit fit_height fit_width original], allow_nil: true}

  # Hash form used by the API and consumed by the reader UI. Only keys
  # whose values are actually set are returned, so the client can layer
  # them on top of its own built-in defaults.
  def reader_defaults
    {
      "spread" => reader_spread,
      "direction" => reader_direction,
      "scale" => reader_scale
    }.compact
  end

  def reader_defaults=(value)
    hash = value.to_h.with_indifferent_access
    self.reader_spread = hash[:spread] if hash.key?(:spread)
    self.reader_direction = hash[:direction] if hash.key?(:direction)
    self.reader_scale = hash[:scale] if hash.key?(:scale)
  end
end
