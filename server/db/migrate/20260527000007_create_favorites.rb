class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites, primary_key: [:user_id, :book_id] do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :favorites, :book_id, name: "index_favorites_on_book_id_only"
  end
end
