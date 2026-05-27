# frozen_string_literal: true

class CreateLibraries < ActiveRecord::Migration[8.1]
  def change
    create_table :libraries do |t|
      t.string :name, null: false
      t.string :path, null: false
      t.datetime :last_scanned_at

      t.timestamps
    end
    add_index :libraries, :name, unique: true
    add_index :libraries, :path, unique: true
  end
end
