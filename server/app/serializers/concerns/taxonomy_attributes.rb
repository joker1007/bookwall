# frozen_string_literal: true

# Shared Alba attribute macros for the taxonomy serializers (Author, Tag,
# Series). Index endpoints batch-preload per-record counts and first books
# into params so we don't fire one query per row; each macro falls back to
# the record's own association for single-record (#show) responses.
module TaxonomyAttributes
  extend ActiveSupport::Concern

  class_methods do
    def book_count_attribute
      attribute :book_count do |record|
        counts = params[:book_counts]
        counts ? counts.fetch(record.id, 0) : record.books.size
      end
    end

    def sample_cover_thumb_attribute
      attribute :sample_cover_thumb_url do |record|
        book = params[:first_books]&.fetch(record.id, nil) || record.first_book
        CoverUrlHelper.cover_thumb_url(book)
      end
    end
  end
end
