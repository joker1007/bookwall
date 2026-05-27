# frozen_string_literal: true

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
        books: serialize_books(books),
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: serialize_book(@book)
    end

    def update
      if @book.update(book_params)
        update_authors if params.key?(:author_names)
        update_tags if params.key?(:tag_names)
        @book.reload
        render json: serialize_book(@book)
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
      render json: serialize_book(@book), status: :created
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

    def serialize_book(book)
      BookSerializer.new(
        book,
        params: {favorite_book_ids: favorite_book_ids([book.id])}
      ).serializable_hash
    end

    def serialize_books(books)
      ids = books.map(&:id)
      BookSerializer.new(
        books,
        params: {favorite_book_ids: favorite_book_ids(ids)}
      ).serializable_hash
    end

    def favorite_book_ids(book_ids)
      return [] if book_ids.empty?
      Favorite.where(user_id: Current.user.id, book_id: book_ids).pluck(:book_id)
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
