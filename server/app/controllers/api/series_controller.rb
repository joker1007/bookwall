# frozen_string_literal: true

module Api
  class SeriesController < BaseController
    before_action :set_series, only: %i[show update destroy]
    before_action :require_series_owner!, only: %i[update destroy]

    def index
      scope = Series.accessible_by(Current.user)
      scope = scope.in_library(params[:library_id]) if params[:library_id].present?
      pagy, items = pagy(:offset, scope.order(:name))
      first_books = Books::FirstBookPreloader.for_series(items, library_ids: accessible_library_ids)
      book_counts = Series.book_counts_for(items, library_ids: accessible_library_ids)
      render json: {
        series: SeriesSerializer.new(
          items,
          params: {first_books: first_books, book_counts: book_counts}
        ).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: SeriesSerializer.new(@series).serializable_hash
    end

    def update
      if @series.update(series_params)
        render json: SeriesSerializer.new(@series).serializable_hash
      else
        render json: {errors: @series.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @series.destroy!
      head :no_content
    end

    private

    def set_series
      @series = Series.accessible_by(Current.user).find(params[:id])
    end

    def require_series_owner!
      raise ManagementForbidden unless @series.library.owner_id == Current.user.id
    end

    def series_params
      params.permit(:name)
    end
  end
end
