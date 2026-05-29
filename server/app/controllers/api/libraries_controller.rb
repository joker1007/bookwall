# frozen_string_literal: true

module Api
  class LibrariesController < BaseController
    before_action :set_readable_library, only: %i[show]
    before_action :set_owned_library, only: %i[update destroy]

    def index
      pagy, libraries = pagy(:offset, accessible_libraries.order(:name))
      render json: {
        libraries: LibrarySerializer.new(libraries, params: serializer_params(libraries)).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: LibrarySerializer.new(@library, params: serializer_params).serializable_hash
    end

    def create
      library = Library.new(library_params.except(:shared_user_ids))
      library.owner = Current.user
      if library.save
        sync_shares(library, library_params[:shared_user_ids])
        render json: LibrarySerializer.new(library, params: serializer_params).serializable_hash, status: :created
      else
        render json: {errors: library.errors.full_messages}, status: :unprocessable_content
      end
    end

    def update
      if @library.update(library_params.except(:shared_user_ids))
        sync_shares(@library, library_params[:shared_user_ids]) if library_params.key?(:shared_user_ids)
        render json: LibrarySerializer.new(@library, params: serializer_params).serializable_hash
      else
        render json: {errors: @library.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @library.destroy!
      head :no_content
    end

    private

    def set_readable_library
      @library = find_accessible_library!(params[:id])
    end

    def set_owned_library
      @library = find_owned_library!(params[:id])
    end

    # Replaces the share set with the requested users, ignoring unknown ids and
    # never sharing back to the owner. nil means "no change requested".
    def sync_shares(library, ids)
      return if ids.nil?
      wanted = User.where(id: Array(ids).map(&:to_i)).where.not(id: library.owner_id).ids
      library.shared_user_ids = wanted
    end

    def serializer_params(libraries = nil)
      result = {current_user_id: Current.user.id}
      if libraries
        shares = LibraryShare.where(library_id: libraries.map(&:id)).group_by(&:library_id)
        result[:shared_user_ids_by_library] = shares.transform_values { |rows| rows.map(&:user_id) }
      end
      result
    end

    def library_params
      params.permit(:name, :path, :auto_scan_enabled, shared_user_ids: [])
    end
  end
end
