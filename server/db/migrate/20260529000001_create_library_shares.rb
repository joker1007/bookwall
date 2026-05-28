# frozen_string_literal: true

class CreateLibraryShares < ActiveRecord::Migration[8.1]
  def change
    create_table :library_shares, primary_key: [:library_id, :user_id] do |t|
      t.references :library, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    # Composite PK covers (library_id, user_id); add the reverse for the hot
    # path "which libraries are shared with this user".
    add_index :library_shares, :user_id, name: "index_library_shares_on_user_id_only"
  end
end
