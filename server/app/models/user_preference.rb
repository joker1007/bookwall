# frozen_string_literal: true

class UserPreference < ApplicationRecord
  belongs_to :user

  PRELOAD_AHEAD_RANGE = (0..16).freeze
  FONT_SIZE_RANGE = (50..300).freeze

  validates :reader_direction, inclusion: {in: %w[ltr rtl], allow_nil: true}
  validates :reader_scale,
    inclusion: {in: %w[fit fit_height fit_width original], allow_nil: true}
  validates :reader_preload_ahead,
    numericality: {only_integer: true, in: PRELOAD_AHEAD_RANGE},
    allow_nil: true
  validates :reader_font_size,
    numericality: {only_integer: true, in: FONT_SIZE_RANGE},
    allow_nil: true
  validates :reader_theme,
    inclusion: {in: %w[light dark sepia], allow_nil: true}
  validates :reader_writing_mode,
    inclusion: {in: %w[auto horizontal vertical], allow_nil: true}

  def reader_defaults
    {
      "spread" => reader_spread,
      "direction" => reader_direction,
      "scale" => reader_scale,
      "preload_ahead" => reader_preload_ahead,
      "font_size" => reader_font_size,
      "theme" => reader_theme,
      "writing_mode" => reader_writing_mode
    }.compact
  end

  def reader_defaults=(value)
    hash = value.to_h.with_indifferent_access
    self.reader_spread = hash[:spread] if hash.key?(:spread)
    self.reader_direction = hash[:direction] if hash.key?(:direction)
    self.reader_scale = hash[:scale] if hash.key?(:scale)
    self.reader_preload_ahead = hash[:preload_ahead] if hash.key?(:preload_ahead)
    self.reader_font_size = hash[:font_size] if hash.key?(:font_size)
    self.reader_theme = hash[:theme] if hash.key?(:theme)
    self.reader_writing_mode = hash[:writing_mode] if hash.key?(:writing_mode)
  end
end
