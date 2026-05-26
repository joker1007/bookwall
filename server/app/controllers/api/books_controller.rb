module Api
  class BooksController < BaseController
    before_action :set_book, only: %i[show update destroy favorite unfavorite]

    def index
      search = Books::Search.new(
        query: params[:q],
        library_id: params[:library_id],
        series_id: params[:series_id],
        author_id: params[:author_id],
        tag_id: params[:tag_id],
        favorite_user_id: favorites_only? ? Current.user.id : nil,
        sort: params[:sort]
      )
      pagy, books = pagy(:offset, search.relation.includes(:authors, :tags, :series))
      render json: {
        books: BookSerializer.new(books).serializable_hash,
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: BookSerializer.new(@book).serializable_hash
    end

    def update
      if @book.update(book_params)
        update_authors if params.key?(:author_names)
        update_tags if params.key?(:tag_names)
        @book.reload
        render json: BookSerializer.new(@book).serializable_hash
      else
        render json: {errors: @book.errors.full_messages}, status: :unprocessable_content
      end
    end

    def destroy
      @book.destroy!
      head :no_content
    end

    def favorite
      Favorite.find_or_create_by!(user: Current.user, book: @book)
      render json: BookSerializer.new(@book).serializable_hash, status: :created
    end

    def unfavorite
      Favorite.where(user: Current.user, book: @book).destroy_all
      head :no_content
    end

    private

    def set_book
      @book = Book.find(params[:id])
    end

    def book_params
      params.permit(:title, :volume, :series_id, :published_at, :page_count)
    end

    def favorites_only?
      ActiveModel::Type::Boolean.new.cast(params[:favorites_only])
    end

    def update_authors
      names = normalize_names(params[:author_names])
      if names.any?
        Author.upsert_all(names.map { |n| {name: n} }, unique_by: :name)
        @book.authors = Author.where(name: names)
      else
        @book.authors = []
      end
    end

    def update_tags
      names = normalize_names(params[:tag_names])
      if names.any?
        Tag.upsert_all(names.map { |n| {name: n} }, unique_by: :name)
        @book.tags = Tag.where(name: names)
      else
        @book.tags = []
      end
    end

    def normalize_names(raw)
      Array(raw).map(&:to_s).map(&:strip).reject(&:empty?).uniq
    end
  end
end
