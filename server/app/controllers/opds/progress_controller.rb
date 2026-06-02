# frozen_string_literal: true

module Opds
  # Progress sync for first-party clients (e.g. the Android app) that
  # authenticate against the OPDS namespace with HTTP Basic. Image formats sync
  # an exact current_page; EPUB syncs epub_cfi + progress_fraction (the Android
  # reader and the web reader both render with foliate-js, so CFIs interoperate).
  class ProgressController < BaseController
    def show
      progress = current_progress
      render json: ReadingProgressSerializer.new(progress).serializable_hash
    end

    def update
      progress = current_progress
      progress.current_page = progress_params[:current_page] if progress_params.key?(:current_page)
      progress.progress_fraction = progress_params[:progress_fraction] if progress_params.key?(:progress_fraction)
      progress.epub_cfi = progress_params[:epub_cfi] if progress_params.key?(:epub_cfi)
      progress.last_read_at = Time.current

      if progress.save
        render json: ReadingProgressSerializer.new(progress).serializable_hash
      else
        render json: {errors: progress.errors.full_messages}, status: :unprocessable_content
      end
    end

    private

    def current_progress
      book = find_accessible_book!(params[:book_id])
      ReadingProgress.find_or_initialize_by(user_id: Current.user.id, book_id: book.id)
    end

    def progress_params
      params.permit(:current_page, :progress_fraction, :epub_cfi).to_h.symbolize_keys
    end
  end
end
