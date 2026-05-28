# frozen_string_literal: true

# Shared behaviour for the global, owner-less metadata records (Author, Tag).
# Both reach books through a join table (BookAuthor / BookTag), so visibility,
# per-record book counts, and the "may the current user manage it?" check all
# follow the same join-and-scope-by-library shape. Configure with
# `represents_book_metadata` to supply the join model and its foreign key.
module GlobalMetadata
  extend ActiveSupport::Concern

  included do
    class_attribute :metadata_join_model, :metadata_foreign_key, instance_accessor: false
  end

  class_methods do
    def represents_book_metadata(join_model:, foreign_key:)
      self.metadata_join_model = join_model
      self.metadata_foreign_key = foreign_key
    end

    # {record_id => book_count} for the given records, counting only books in
    # the supplied (already access-scoped) library ids.
    def book_counts_for(records, library_ids:)
      metadata_join_model.joins(:book)
        .where(metadata_foreign_key => records.map(&:id), books: {library_id: library_ids})
        .group(metadata_foreign_key).count
    end
  end

  # True when this record carries at least one book in one of the given
  # libraries — i.e. the current user may rename/delete it. Callers pass the
  # *owned* library ids so shared (read-only) users are excluded.
  def manageable_via?(library_ids)
    self.class.metadata_join_model.joins(:book)
      .where(self.class.metadata_foreign_key => id, books: {library_id: library_ids})
      .exists?
  end
end
