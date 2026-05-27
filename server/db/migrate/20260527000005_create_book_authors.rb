# frozen_string_literal: true

class CreateBookAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :book_authors, primary_key: [:book_id, :author_id] do |t|
      t.references :book, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: true
    end
    add_index :book_authors, :author_id, name: "index_book_authors_on_author_id_only"
  end
end
