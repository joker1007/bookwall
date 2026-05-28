# frozen_string_literal: true

class ReadingProgress < ApplicationRecord
  self.primary_key = %i[user_id book_id]

  belongs_to :user
  belongs_to :book

  scope :for_user, ->(user) { where(user_id: user.id) }
  # Rows the user has actually opened. last_read_at is NOT NULL today, so this
  # is a defensive guard preserving the recent-reads query's original intent.
  scope :read, -> { where.not(last_read_at: nil) }
  scope :in_libraries, ->(library_ids) { joins(:book).where(books: {library_id: library_ids}) }

  validates :current_page, numericality: {only_integer: true, greater_than_or_equal_to: 0}

  # Settings are stored as a JSON string. Expose them as a Hash via these
  # helpers so callers don't have to deal with parsing/serializing.
  def settings
    return {} if settings_json.blank?
    JSON.parse(settings_json)
  rescue JSON::ParserError
    {}
  end

  def settings=(value)
    self.settings_json = value.nil? ? nil : JSON.generate(value)
  end
end
