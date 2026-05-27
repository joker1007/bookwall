# frozen_string_literal: true

module Books
  # Batch-resolve the "first book" of each Series / Author / Tag in a
  # collection so the taxonomy index pages can render thumbnails without
  # firing the N queries (book lookup) + 3N queries (Active Storage
  # cover preload) that calling `record.first_book` per row would.
  #
  # Each method returns a Hash<parent_id, Book> where the returned Book
  # already has its cover attachment / blob / variant_records preloaded.
  module FirstBookPreloader
    module_function

    # Series.first_book picks the earliest volume (NULLs last). Uses a
    # correlated subquery to find one book id per series, then loads
    # those books in a single query with cover preloads chained.
    def for_series(series_records)
      ids = series_records.map(&:id)
      return {} if ids.empty?

      first_book_ids = Book
        .where(series_id: ids)
        .where(<<~SQL.squish)
          books.id = (
            SELECT b2.id FROM books b2
            WHERE b2.series_id = books.series_id
            ORDER BY CASE WHEN b2.volume IS NULL THEN 1 ELSE 0 END,
                     b2.volume ASC,
                     b2.id ASC
            LIMIT 1
          )
        SQL
        .pluck(:id)

      Book.where(id: first_book_ids).with_attached_cover.index_by(&:series_id)
    end

    # Author / Tag join through the book_authors / book_tags tables; the
    # first book is the earliest added_at. The pattern below works for
    # any HABTM-style "first per parent" lookup — pass the join model
    # name and the foreign key.
    def for_authors(author_records)
      first_book_per_join("book_authors", :author_id, author_records.map(&:id))
    end

    def for_tags(tag_records)
      first_book_per_join("book_tags", :tag_id, tag_records.map(&:id))
    end

    def first_book_per_join(join_table, foreign_key, ids)
      return {} if ids.empty?

      rows = ActiveRecord::Base.connection.select_rows(
        ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, ids])
          SELECT joins.#{foreign_key}, joins.book_id
          FROM #{join_table} joins
          INNER JOIN books ON books.id = joins.book_id
          WHERE joins.#{foreign_key} IN (?)
            AND books.id = (
              SELECT b2.id FROM books b2
              INNER JOIN #{join_table} j2 ON j2.book_id = b2.id
              WHERE j2.#{foreign_key} = joins.#{foreign_key}
              ORDER BY b2.added_at ASC, b2.id ASC
              LIMIT 1
            )
        SQL
      )

      books = Book.where(id: rows.map { |_, book_id| book_id })
        .with_attached_cover
        .index_by(&:id)
      rows.to_h { |parent_id, book_id| [parent_id, books[book_id]] }
    end
    private_class_method :first_book_per_join
  end
end
