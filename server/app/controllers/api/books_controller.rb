# frozen_string_literal: true

module Api
  class BooksController < BaseController
    include ByteRangeServing
    before_action :set_book, only: %i[show update destroy favorite unfavorite file next_in_series]
    before_action :require_book_owner!, only: %i[update destroy]

    def index
      search = Books::Search.new(
        query: params[:q],
        library_id: params[:library_id],
        series_id: params[:series_id],
        author_id: params[:author_id],
        tag_id: params[:tag_id],
        collection_id: own_collection_id,
        favorite_user_id: favorites_only? ? Current.user.id : nil,
        sort: params[:sort],
        base_scope: accessible_books
      )
      # The client virtualizes the list DOM, so the full result set is
      # returned in one response instead of paginating.
      books = search.relation
        .includes(:authors, :tags, :series)
        .with_attached_cover
        .load
      render json: {
        books: serialize_books(books),
        count: books.size
      }
    end

    def show
      render json: serialize_book(@book)
    end

    def next_in_series
      next_book = @book.next_in_series(accessible_books)
      return head :no_content unless next_book
      render json: serialize_book(next_book)
    end

    def update
      ActiveRecord::Base.transaction do
        @book.update!(book_params)
        @book.replace_authors(params[:author_names]) if params.key?(:author_names)
        @book.replace_tags(params[:tag_names]) if params.key?(:tag_names)
      end
      @book.reload
      render json: serialize_book(@book)
    rescue ActiveRecord::RecordInvalid
      render json: {errors: @book.errors.full_messages}, status: :unprocessable_content
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

    def bulk_favorite
      rows = accessible_books.where(id: bulk_ids).ids.map do |book_id|
        {user_id: Current.user.id, book_id: book_id, created_at: Time.current}
      end
      Favorite.upsert_all(rows, unique_by: %i[user_id book_id]) if rows.any?
      head :no_content
    end

    def bulk_unfavorite
      Favorite.where(user_id: Current.user.id, book_id: bulk_ids).delete_all
      head :no_content
    end

    # Only books in owned libraries are destroyed; shared books are skipped.
    def bulk_destroy
      accessible_books.where(id: bulk_ids, library_id: owned_library_ids).destroy_all
      head :no_content
    end

    def file
      return head :not_found if @book.file_format == "image_dir"

      resolved = @book.absolute_path
      library_root = File.expand_path(@book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        return head :forbidden
      end

      etag = @book.updated_at.to_i.to_s
      response.set_header("Cache-Control", "private, max-age=31536000, immutable")
      response.set_header("Accept-Ranges", "bytes")
      return unless stale?(strong_etag: etag)

      mime = Books::FileFormat.mime(@book.file_format)
      filename = Books::FileFormat.download_filename(@book)
      return if serve_byte_range(resolved, type: mime, filename: filename)

      send_file resolved, type: mime, disposition: "attachment", filename: filename
    end

    private

    def set_book
      @book = find_accessible_book!(params[:id])
    end

    def require_book_owner!
      raise ManagementForbidden unless @book.library.owner_id == Current.user.id
    end

    def book_params
      params.permit(:title, :volume, :series_id, :published_at, :page_count)
    end

    def favorites_only?
      ActiveModel::Type::Boolean.new.cast(params[:favorites_only])
    end

    def bulk_ids
      Array(params[:book_ids]).map(&:to_i)
    end

    # Scoped to Current.user so a foreign id is 404, not a leak.
    def own_collection_id
      return nil if params[:collection_id].blank?
      Current.user.collections.find(params[:collection_id]).id
    end

    def serialize_book(book)
      BookSerializer.new(
        book,
        params: {
          favorite_book_ids: Favorite.book_ids_for(Current.user, [book.id]),
          reading_progress_by_book_id: ReadingProgress.by_book_id_for(Current.user, [book.id])
        }
      ).serializable_hash
    end

    def serialize_books(books)
      ids = books.map(&:id)
      BookSerializer.new(
        books,
        params: {
          favorite_book_ids: Favorite.book_ids_for(Current.user, ids),
          reading_progress_by_book_id: ReadingProgress.by_book_id_for(Current.user, ids)
        }
      ).serializable_hash
    end
  end
end
