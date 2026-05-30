# frozen_string_literal: true

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

    def book_counts_for(records, library_ids:)
      metadata_join_model.joins(:book)
        .where(metadata_foreign_key => records.map(&:id), books: {library_id: library_ids})
        .group(metadata_foreign_key).count
    end

    def upsert_by_name(names)
      cleaned = Array(names).map { |n| n.to_s.strip }.reject(&:empty?).uniq
      return [] if cleaned.empty?
      upsert_all(cleaned.map { |n| {name: n} }, unique_by: :name)
      where(name: cleaned).to_a
    end
  end

  # Pass *owned* library ids only, so shared (read-only) users are excluded.
  def manageable_via?(library_ids)
    self.class.metadata_join_model.joins(:book)
      .where(self.class.metadata_foreign_key => id, books: {library_id: library_ids})
      .exists?
  end
end
