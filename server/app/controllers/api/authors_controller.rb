module Api
  class AuthorsController < BaseController
    before_action :set_author, only: %i[show update destroy]

    def index
      pagy, items = pagy(:offset, Author.order(:name))
      render json: {
        authors: AuthorSerializer.new(items).serializable_hash,
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
      @author = Author.find(params[:id])
    end

    def author_params
      params.permit(:name)
    end
  end
end
