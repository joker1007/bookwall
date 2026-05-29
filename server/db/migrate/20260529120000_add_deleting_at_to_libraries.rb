# frozen_string_literal: true

class AddDeletingAtToLibraries < ActiveRecord::Migration[8.1]
  def change
    add_column :libraries, :deleting_at, :datetime
    add_index :libraries, :deleting_at
  end
end
