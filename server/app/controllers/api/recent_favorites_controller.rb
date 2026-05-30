# frozen_string_literal: true

module Api
  class RecentFavoritesController < BaseController
    LIMIT = 25

    def index
      favorites = Favorite
        .for_user(Current.user)
        .in_libraries(accessible_library_ids)
        .order(created_at: :desc)
        .limit(LIMIT)
        .includes(book: [:authors, :tags, :series, {cover_attachment: :blob}])

      books = favorites.map(&:book)
      ids = books.map(&:id)
      render json: {
        books: BookSerializer.new(
          books,
          params: {
            favorite_book_ids: ids,
            reading_progress_by_book_id: ReadingProgress.by_book_id_for(Current.user, ids)
          }
        ).serializable_hash
      }
    end
  end
end
