# frozen_string_literal: true

class CreateBookTags < ActiveRecord::Migration[8.1]
  def change
    create_table :book_tags, primary_key: [:book_id, :tag_id] do |t|
      t.references :book, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
    end
    add_index :book_tags, :tag_id, name: "index_book_tags_on_tag_id_only"
  end
end
