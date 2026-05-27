module Api
  class ReadingProgressesController < BaseController
    before_action :set_book

    def show
      progress = current_progress
      render json: ReadingProgressSerializer.new(progress).serializable_hash
    end

    def update
      progress = current_progress
      progress.current_page = progress_params[:current_page] if progress_params.key?(:current_page)
      progress.settings = progress_params[:settings] if progress_params.key?(:settings)
      progress.last_read_at = Time.current

      if progress.save
        render json: ReadingProgressSerializer.new(progress).serializable_hash
      else
        render json: {errors: progress.errors.full_messages}, status: :unprocessable_content
      end
    end

    private

    def set_book
      @book = Book.find(params[:book_id])
    end

    # Returns the existing row or a blank in-memory one so show/update can
    # share the same upsert path. Don't seed `last_read_at` here — clients
    # rely on `last_read_at === null` in the show response to detect a
    # never-opened book and fall back to user-wide reader defaults.
    def current_progress
      ReadingProgress.find_or_initialize_by(user_id: Current.user.id, book_id: @book.id)
    end

    def progress_params
      params.permit(:current_page, settings: {}).to_h.symbolize_keys
    end
  end
end
