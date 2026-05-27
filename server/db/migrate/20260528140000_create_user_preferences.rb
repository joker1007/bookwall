# frozen_string_literal: true

class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: {unique: true}
      # Reader-related defaults applied when a book has no per-book
      # ReadingProgress yet. Every column is nullable so absence falls
      # through to the global defaults defined in the client.
      #
      # CBZ / PDF / image_dir
      t.boolean :reader_spread
      t.string :reader_direction
      t.string :reader_scale
      # Pages to fetch into the browser cache ahead of the current
      # spread (0..16, default 4 on the client).
      t.integer :reader_preload_ahead
      # EPUB
      # font size as a percentage 50..300, theme light/dark/sepia,
      # writing_mode auto/horizontal/vertical.
      t.integer :reader_font_size
      t.string :reader_theme
      t.string :reader_writing_mode
      t.timestamps
    end
  end
end
