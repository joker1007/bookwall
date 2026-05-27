# frozen_string_literal: true

class CreateReadingProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :reading_progresses, primary_key: %i[user_id book_id] do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      # 0-indexed page (OPDS-PSE convention).
      t.integer :current_page, null: false, default: 0
      t.datetime :last_read_at, null: false
      # Reader settings (spread, direction, ...) stored as JSON text for
      # per-book customization.
      t.text :settings_json
      # EPUB position. Saved as the canonical fragment identifier
      # returned by foliate-js's `relocate` event so we can restore the
      # reader exactly where the user left off.
      t.string :epub_cfi
      # 0..1 progress for EPUB, sourced from foliate-js's relocate
      # event. Used for the cover progress-bar overlay.
      t.float :progress_fraction
      t.timestamps
    end
    add_index :reading_progresses, :book_id, name: "index_reading_progresses_on_book_id_only"
  end
end
