# frozen_string_literal: true

class AddEpubColumns < ActiveRecord::Migration[8.1]
  def change
    # Per-book EPUB position. Saved as the canonical fragment identifier
    # returned by foliate-js's `relocate` event so we can restore the
    # reader exactly where the user left off.
    add_column :reading_progresses, :epub_cfi, :string

    # EPUB reader defaults (font size as a percentage 50..300, theme as
    # one of light/dark/sepia, writing_mode horizontal/vertical). Nullable
    # so absence falls through to the client default.
    add_column :user_preferences, :reader_font_size, :integer
    add_column :user_preferences, :reader_theme, :string
    add_column :user_preferences, :reader_writing_mode, :string
  end
end
