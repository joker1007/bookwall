# frozen_string_literal: true

module Api
  class CollectionsController < BaseController
    before_action :set_collection, only: %i[show update destroy]

    def index
      pagy, items = pagy(:offset, Current.user.collections.order(:name))
      first_books = Books::FirstBookPreloader.for_collections(items, library_ids: accessible_library_ids)
      book_counts = Collection.book_counts_for(items, library_ids: accessible_library_ids)
      render json: {
        collections: CollectionSerializer.new(
          items,
          params: {first_books: first_books, book_counts: book_counts}
        ).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: CollectionSerializer.new(@collection).serializable_hash
    end

    def create
      collection = Current.user.collections.new(collection_params)
      if collection.save
        render json: CollectionSerializer.new(collection).serializable_hash, status: :created
      else
        render json: {errors: collection.errors.full_messages}, status: :unprocessable_content
      end
    end

    def update
      if @collection.update(collection_params)
        render json: CollectionSerializer.new(@collection).serializable_hash
      else
        render json: {errors: @collection.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @collection.destroy!
      head :no_content
    end

    private

    # Collections are user-private: scope every lookup to the current user so
    # another user's collection (or a bogus id) is a 404, not a leak.
    def set_collection
      @collection = Current.user.collections.find(params[:id])
    end

    def collection_params
      params.permit(:name)
    end
  end
end
