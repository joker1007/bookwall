module Api
  class LibrariesController < BaseController
    before_action :set_library, only: %i[show update destroy]

    def index
      pagy, libraries = pagy(:offset, Library.order(:name))
      render json: {
        libraries: LibrarySerializer.new(libraries).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: LibrarySerializer.new(@library).serializable_hash
    end

    def create
      library = Library.new(library_params)
      if library.save
        render json: LibrarySerializer.new(library).serializable_hash, status: :created
      else
        render json: {errors: library.errors.full_messages}, status: :unprocessable_content
      end
    end

    def update
      if @library.update(library_params)
        render json: LibrarySerializer.new(@library).serializable_hash
      else
        render json: {errors: @library.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @library.destroy!
      head :no_content
    end

    private

    def set_library
      @library = Library.find(params[:id])
    end

    def library_params
      params.permit(:name, :path)
    end
  end
end
