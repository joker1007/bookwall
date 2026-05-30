# frozen_string_literal: true

module Books
  # Batches all FTS writes into one transaction so SQLite's FTS5 writer lock
  # is acquired once per run rather than once per row.
  class FtsSyncJob < ApplicationJob
    queue_as :default

    retry_on ActiveRecord::StatementInvalid, attempts: 3, wait: 1.second

    def perform(book_ids, op)
      ids = Array(book_ids).map(&:to_i).uniq
      return if ids.empty?

      case op.to_s
      when "upsert"
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
