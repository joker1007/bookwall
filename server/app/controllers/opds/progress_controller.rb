# frozen_string_literal: true

module Opds
  # Push-only progress sync for first-party clients (e.g. the Android app) that
  # authenticate against the OPDS namespace with HTTP Basic. Page-based formats
  # only: EPUB position lives in epub_cfi and is owned by the web reader.
  class ProgressController < BaseController
    def update
      book = find_accessible_book!(params[:book_id])
      progress = ReadingProgress.find_or_initialize_by(user_id: Current.user.id, book_id: book.id)

      progress.current_page = progress_params[:current_page] if progress_params.key?(:current_page)
      progress.progress_fraction = progress_params[:progress_fraction] if progress_params.key?(:progress_fraction)
      progress.last_read_at = Time.current

      if progress.save
        render json: ReadingProgressSerializer.new(progress).serializable_hash
      else
        render json: {errors: progress.errors.full_messages}, status: :unprocessable_content
      end
    end

    private

    def progress_params
      params.permit(:current_page, :progress_fraction).to_h.symbolize_keys
    end
  end
end
