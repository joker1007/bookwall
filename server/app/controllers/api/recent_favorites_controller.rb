# frozen_string_literal: true

module Api
  # Books the current user has favorited, ordered by the most recent
  # favorite creation time. Powers the home page's "Favorites" carousel.
  class RecentFavoritesController < BaseController
    LIMIT = 25

    def index
      favorites = Favorite
        .where(user_id: Current.user.id)
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
            reading_progress_by_book_id: reading_progress_by_book_id(ids)
          }
        ).serializable_hash
      }
    end

    private

    def reading_progress_by_book_id(ids)
      return {} if ids.empty?
      ReadingProgress
        .where(user_id: Current.user.id, book_id: ids)
        .index_by(&:book_id)
    end
  end
end
