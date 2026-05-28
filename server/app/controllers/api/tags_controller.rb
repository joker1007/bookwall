# frozen_string_literal: true

module Api
  class TagsController < BaseController
    before_action :set_tag, only: %i[show update destroy]
    before_action :require_tag_manageable!, only: %i[update destroy]

    def index
      pagy, items = pagy(:offset, Tag.accessible_by(Current.user).order(:name))
      book_counts = Tag.book_counts_for(items, library_ids: accessible_library_ids)
      render json: {
        tags: TagSerializer.new(
          items,
          params: {book_counts: book_counts}
        ).serializable_hash,
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
      @tag = Tag.accessible_by(Current.user).find(params[:id])
    end

    # Tags are global metadata with no owner. To preserve the read-only
    # guarantee for shared users, only allow rename/delete when the tag is
    # reachable through a library the current user owns.
    def require_tag_manageable!
      raise ManagementForbidden unless @tag.manageable_via?(owned_library_ids)
    end

    def tag_params
      params.permit(:name)
    end
  end
end
