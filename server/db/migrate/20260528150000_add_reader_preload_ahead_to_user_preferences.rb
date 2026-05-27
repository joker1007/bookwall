# frozen_string_literal: true

class AddReaderPreloadAheadToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    # How many pages ahead of the current spread to preload in the reader.
    # Nullable so absence means "fall through to the client default" (4).
    add_column :user_preferences, :reader_preload_ahead, :integer
  end
end
