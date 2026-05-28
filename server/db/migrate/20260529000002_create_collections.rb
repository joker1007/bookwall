# frozen_string_literal: true

class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :collections, [:user_id, :name], unique: true

    create_table :collection_books, primary_key: [:collection_id, :book_id] do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :collection_books, :book_id, name: "index_collection_books_on_book_id_only"
  end
end
