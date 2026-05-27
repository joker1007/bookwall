# frozen_string_literal: true

class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: {unique: true}
      # Reader-related defaults applied when a book has no per-book
      # ReadingProgress yet. Nullable so absence falls through to the
      # global defaults defined in the client.
      t.boolean :reader_spread
      t.string :reader_direction
      t.string :reader_scale
      t.timestamps
    end
  end
end
