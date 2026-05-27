# frozen_string_literal: true

module Books
  module FtsIndex
    module_function

    def upsert(book)
      delete(book.id)
      sql = ActiveRecord::Base.sanitize_sql_array([
        "INSERT INTO books_fts (rowid, title, series_name, authors) VALUES (?, ?, ?, ?)",
        book.id,
        book.title.to_s,
        book.series&.name.to_s,
        book.authors.pluck(:name).join(" ")
      ])
      ActiveRecord::Base.connection.execute(sql)
    end

    def delete(id)
      sql = ActiveRecord::Base.sanitize_sql_array(["DELETE FROM books_fts WHERE rowid = ?", id])
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
