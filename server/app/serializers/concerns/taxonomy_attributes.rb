# frozen_string_literal: true

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
