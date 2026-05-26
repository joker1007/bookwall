class CreateBooksFts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE books_fts USING fts5(
        title,
        series_name,
        authors,
        tokenize='unicode61 remove_diacritics 2'
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS books_fts"
  end
end
