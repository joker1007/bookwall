# frozen_string_literal: true

# file_hash was originally used as the ETag for the book-bytes /
# page-bytes endpoints, but computing SHA256 of every book during a
# library scan was disproportionately expensive (especially for large
# PDFs). updated_at alone is enough to invalidate browser caches when
# the scanner re-imports a file, so drop the column.
class DropFileHashFromBooks < ActiveRecord::Migration[8.1]
  def change
    remove_index :books, :file_hash, if_exists: true
    remove_column :books, :file_hash, :string, limit: 64
  end
end
