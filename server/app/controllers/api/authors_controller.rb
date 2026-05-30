# frozen_string_literal: true

module Api
  class AuthorsController < BaseController
    before_action :set_author, only: %i[show update destroy]
    before_action :require_author_manageable!, only: %i[update destroy]

    def index
      pagy, items = pagy(:offset, Author.accessible_by(Current.user).order(:name))
      first_books = Books::FirstBookPreloader.for_authors(items, library_ids: accessible_library_ids)
      book_counts = Author.book_counts_for(items, library_ids: accessible_library_ids)
      render json: {
        authors: AuthorSerializer.new(
          items,
          params: {first_books: first_books, book_counts: book_counts}
        ).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: AuthorSerializer.new(@author).serializable_hash
    end

    def update
      if @author.update(author_params)
        render json: AuthorSerializer.new(@author).serializable_hash
      else
        render json: {errors: @author.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @author.destroy!
      head :no_content
    end

    private

    def set_author
      @author = Author.accessible_by(Current.user).find(params[:id])
    end

    # Global metadata: only manageable via an owned library (read-only for shared users).
    def require_author_manageable!
      raise ManagementForbidden unless @author.manageable_via?(owned_library_ids)
    end

    def author_params
      params.permit(:name)
    end
  end
end
