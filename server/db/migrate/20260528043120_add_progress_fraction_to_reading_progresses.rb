# frozen_string_literal: true

# foliate-js's relocate event exposes a 0..1 `fraction` for where the
# reader currently is in the book. Storing it lets the home carousel
# and book cover overlay show a real progress bar for EPUB the same way
# CBZ / PDF do via current_page.
class AddProgressFractionToReadingProgresses < ActiveRecord::Migration[8.1]
  def change
    add_column :reading_progresses, :progress_fraction, :float
  end
end
