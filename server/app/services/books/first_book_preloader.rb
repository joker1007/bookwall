# frozen_string_literal: true

module Books
  # Batch-resolve the "first book" of each Series / Author / Tag in a
  # collection so the taxonomy index pages can render thumbnails without
  # firing the N queries (book lookup) + 3N queries (Active Storage
  # cover preload) that calling `record.first_book` per row would.
  #
  # Each method returns a Hash<parent_id, Book> where the returned Book
  # already has its cover attachment / blob / variant_records preloaded.
  #
  # Pass library_ids to restrict the sample book to accessible libraries so a
  # tag/author spanning a private library does not leak a cover from it. nil
  # means "no restriction".
  module FirstBookPreloader
    module_function

    # Series.first_book picks the earliest volume (NULLs last). Uses a
    # correlated subquery to find one book id per series, then loads
    # those books in a single query with cover preloads chained.
    def for_series(series_records, library_ids: nil)
      ids = series_records.map(&:id)
      return {} if ids.empty?

      scope = Book.where(series_id: ids)
      scope = scope.where(library_id: library_ids) if library_ids
      first_book_ids = scope
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

    # Author joins through the book_authors table; the first book is the
    # earliest added_at. The pattern below works for any HABTM-style
    # "first per parent" lookup — pass the join model name and foreign key.
    def for_authors(author_records, library_ids: nil)
      first_book_per_join("book_authors", :author_id, author_records.map(&:id), library_ids: library_ids)
    end

    # Collections group books through collection_books; the first book is the
    # earliest added_at, same shape as authors.
    def for_collections(collection_records, library_ids: nil)
      first_book_per_join("collection_books", :collection_id, collection_records.map(&:id), library_ids: library_ids)
    end

    def first_book_per_join(join_table, foreign_key, ids, library_ids: nil)
      return {} if ids.empty?

      # foreign_key / join_table are internal constants, not user input.
      outer_lib = library_ids ? "AND books.library_id IN (:library_ids)" : ""
      inner_lib = library_ids ? "AND b2.library_id IN (:library_ids)" : ""

      rows = ActiveRecord::Base.connection.select_rows(
        ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, {ids: ids, library_ids: library_ids}])
          SELECT joins.#{foreign_key}, joins.book_id
          FROM #{join_table} joins
          INNER JOIN books ON books.id = joins.book_id
          WHERE joins.#{foreign_key} IN (:ids)
            #{outer_lib}
            AND books.id = (
              SELECT b2.id FROM books b2
              INNER JOIN #{join_table} j2 ON j2.book_id = b2.id
              WHERE j2.#{foreign_key} = joins.#{foreign_key}
                #{inner_lib}
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
