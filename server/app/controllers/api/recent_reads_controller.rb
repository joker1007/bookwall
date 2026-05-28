# frozen_string_literal: true

module Api
  # Books the current user has opened in the reader, ordered by the
  # most-recent ReadingProgress timestamp. Powers the home page's
  # "Continue reading" carousel.
  class RecentReadsController < BaseController
    LIMIT = 25

    def index
      progresses = ReadingProgress
        .for_user(Current.user)
        .read
        .in_libraries(accessible_library_ids)
        .order(last_read_at: :desc)
        .limit(LIMIT)
        .includes(book: [:authors, :tags, :series, {cover_attachment: :blob}])

      books = progresses.map(&:book)
      # We already loaded the user's progress for every book — pass it
      # through to BookSerializer so the home carousel can show progress
      # bars without a second round trip.
      progress_by_book_id = progresses.index_by(&:book_id)
      render json: {
        books: BookSerializer.new(
          books,
          params: {
            favorite_book_ids: Favorite.book_ids_for(Current.user, books.map(&:id)),
            reading_progress_by_book_id: progress_by_book_id
          }
        ).serializable_hash
      }
    end
  end
end
