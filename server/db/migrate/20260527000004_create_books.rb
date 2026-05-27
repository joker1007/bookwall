# frozen_string_literal: true

class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.references :library, null: false, foreign_key: true
      t.references :series, foreign_key: true
      t.string :title, null: false
      t.integer :volume
      t.string :file_path, null: false
      t.integer :file_format, null: false
      t.bigint :file_size, null: false, default: 0
      t.integer :page_count
      t.date :published_at
      t.datetime :added_at, null: false
      t.datetime :scanned_at

      t.timestamps
    end
    # file_path is stored relative to the owning library's root, so the
    # uniqueness scope has to include library_id (two libraries can
    # legitimately hold a file with the same basename).
    add_index :books, %i[library_id file_path], unique: true
    add_index :books, :added_at
    add_index :books, [:library_id, :series_id, :volume]
  end
end
