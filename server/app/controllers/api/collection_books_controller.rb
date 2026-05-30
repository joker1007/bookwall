# frozen_string_literal: true

module Api
  # Shared read-only books may be collected too (collecting doesn't mutate them).
  class CollectionBooksController < BaseController
    before_action :set_collection

    def create
      books = accessible_books.where(id: Array(params[:book_ids]))
      @collection.add_books(books)
      head :no_content
    end

    def destroy
      @collection.collection_books.where(book_id: params[:id]).delete_all
      head :no_content
    end

    private

    def set_collection
      @collection = Current.user.collections.find(params[:collection_id])
    end
  end
end
