module Books
  # Updates the books_fts virtual table for a batch of books asynchronously.
  # Library scans collect every touched book id and enqueue this job once
  # per op at the end, so the scanner doesn't pay FTS5's writer-lock churn
  # in line. Single-book API edits enqueue a one-element array.
  #
  # All FTS writes in a single perform run inside a single transaction —
  # FTS5's internal sub-tables (books_fts_data, books_fts_idx, ...) get
  # rewritten in one commit so the SQLite writer is held for one lock
  # acquisition cycle rather than one per row.
  class FtsSyncJob < ApplicationJob
    queue_as :default

    # Only retry on SQLite BUSY contention — other DB errors (constraint
    # violations etc.) are logic bugs and should surface immediately.
    retry_on ActiveRecord::StatementInvalid, attempts: 3, wait: 1.second

    def perform(book_ids, op)
      ids = Array(book_ids).map(&:to_i).uniq
      return if ids.empty?

      case op.to_s
      when "upsert"
        # find_each + ordered ensures stable behavior on big batches; the
        # surrounding transaction collapses each row's DELETE+INSERT into
        # a single writer-lock cycle.
        ActiveRecord::Base.transaction do
          Book.where(id: ids).find_each do |book|
            Books::FtsIndex.upsert(book)
          end
        end
      when "delete"
        ActiveRecord::Base.transaction do
          ids.each { |id| Books::FtsIndex.delete(id) }
        end
      else
        raise ArgumentError, "unknown FTS op: #{op.inspect}"
      end
    end
  end
end
