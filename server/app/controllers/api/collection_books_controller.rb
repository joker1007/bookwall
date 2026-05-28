# frozen_string_literal: true

module Api
  # Membership of books within a (user-private) collection. Books are added by
  # id; only books the user can see (accessible_books) may be collected, but
  # since collecting never mutates the book or its library, shared read-only
  # books are allowed too.
  class CollectionBooksController < BaseController
    before_action :set_collection

    # POST /api/collections/:collection_id/books  { book_ids: [...] }
    def create
      books = accessible_books.where(id: Array(params[:book_ids]))
      @collection.add_books(books)
      head :no_content
    end

    # DELETE /api/collections/:collection_id/books/:id  (id = book id)
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
