# frozen_string_literal: true

class ReadingProgress < ApplicationRecord
  self.primary_key = %i[user_id book_id]

  belongs_to :user
  belongs_to :book

  scope :for_user, ->(user) { where(user_id: user.id) }
  # Defensive: last_read_at is currently NOT NULL, but this preserves recent-reads intent.
  scope :read, -> { where.not(last_read_at: nil) }
  scope :in_libraries, ->(library_ids) { joins(:book).where(books: {library_id: library_ids}) }

  def self.by_book_id_for(user, book_ids)
    return {} if book_ids.empty?
    for_user(user).where(book_id: book_ids).index_by(&:book_id)
  end

  validates :current_page, numericality: {only_integer: true, greater_than_or_equal_to: 0}

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
