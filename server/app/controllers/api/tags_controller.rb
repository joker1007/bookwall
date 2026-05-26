module Api
  class TagsController < BaseController
    before_action :set_tag, only: %i[show update destroy]

    def index
      pagy, items = pagy(:offset, Tag.order(:name))
      render json: {
        tags: TagSerializer.new(items).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: TagSerializer.new(@tag).serializable_hash
    end

    def update
      if @tag.update(tag_params)
        render json: TagSerializer.new(@tag).serializable_hash
      else
        render json: {errors: @tag.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @tag.destroy!
      head :no_content
    end

    private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def tag_params
      params.permit(:name)
    end
  end
end
