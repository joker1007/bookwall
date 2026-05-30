# frozen_string_literal: true

module Api
  class BooksController < BaseController
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
      pagy, books = pagy(
        :offset,
        search.relation
          .includes(:authors, :tags, :series)
          .with_attached_cover
      )
      render json: {
        books: serialize_books(books),
        pagination: pagy_metadata(pagy)
      }
    end

    def show
      render json: serialize_book(@book)
    end

    # GET /api/books/:id/next_in_series
    # Returns the next book in the same series (within the user's accessible
    # scope), or 204 when this is the last volume / has no series. The reader
    # uses this to roll over to the next book when the last page is reached.
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

    # POST /api/books/bulk_favorite  { book_ids: [...] }
    # Favorite every accessible book in the list (idempotent).
    def bulk_favorite
      rows = accessible_books.where(id: bulk_ids).ids.map do |book_id|
        {user_id: Current.user.id, book_id: book_id, created_at: Time.current}
      end
      Favorite.upsert_all(rows, unique_by: %i[user_id book_id]) if rows.any?
      head :no_content
    end

    # DELETE /api/books/bulk_favorite  { book_ids: [...] }
    def bulk_unfavorite
      Favorite.where(user_id: Current.user.id, book_id: bulk_ids).delete_all
      head :no_content
    end

    # POST /api/books/bulk_destroy  { book_ids: [...] }
    # Deletes metadata only, and only for books the user owns — shared
    # (read-only) books in the selection are left untouched.
    def bulk_destroy
      accessible_books.where(id: bulk_ids, library_id: owned_library_ids).destroy_all
      head :no_content
    end

    # GET /api/books/:id/file
    # Streams the raw book file (.epub / .cbz / .pdf) to the SPA, used by
    # the in-browser EPUB reader (foliate-js) and any other download flow.
    # image_dir books aren't single files, so they 404.
    def file
      return head :not_found if @book.file_format == "image_dir"

      resolved = @book.absolute_path
      library_root = File.expand_path(@book.library.path)
      unless resolved == library_root || resolved.start_with?("#{library_root}/")
        return head :forbidden
      end

      # The library scanner bumps updated_at whenever the file is
      # re-ingested, so it's a good enough cache key.
      etag = @book.updated_at.to_i.to_s
      response.set_header("Cache-Control", "private, max-age=31536000, immutable")
      # Advertise range support so pdfjs (and other range-aware clients)
      # fetch only the byte ranges they need instead of the whole file.
      response.set_header("Accept-Ranges", "bytes")
      return unless stale?(etag: etag)

      return if serve_byte_range(resolved)

      send_file resolved,
        type: Books::FileFormat.mime(@book.file_format),
        disposition: "attachment",
        filename: Books::FileFormat.download_filename(@book)
    end

    private

    # Handle a single HTTP Range request with a 206 partial response. Returns
    # false (so the caller falls back to the full send_file) when there's no
    # range header or the request asks for multiple ranges (multipart, which
    # pdfjs never does). Falcon's send_file doesn't honour Range on its own,
    # so we slice the bytes ourselves.
    def serve_byte_range(path)
      range_header = request.get_header("HTTP_RANGE")
      return false if range_header.blank?

      file_size = File.size(path)
      ranges = Rack::Utils.get_byte_ranges(range_header, file_size)
      return false if ranges.nil?

      if ranges.empty?
        response.set_header("Content-Range", "bytes */#{file_size}")
        head :range_not_satisfiable
        return true
      end

      # Multipart (multiple ranges) is something pdfjs never asks for; fall
      # back to the full body rather than build a multipart/byteranges body.
      return false if ranges.size != 1

      range = ranges.first
      response.set_header("Content-Range", "bytes #{range.begin}-#{range.end}/#{file_size}")
      send_data File.binread(path, range.size, range.begin),
        type: Books::FileFormat.mime(@book.file_format),
        disposition: "attachment",
        filename: Books::FileFormat.download_filename(@book),
        status: :partial_content
      true
    end

    def set_book
      @book = find_accessible_book!(params[:id])
    end

    # Editing/deleting book metadata mutates library content — owner only.
    # Shared (read-only) users get 403; the book is already known-visible.
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

    # Resolve the collection_id filter only when it belongs to the current
    # user — a foreign/bogus id raises 404 rather than leaking another user's
    # curation. Returns nil when no collection filter was requested.
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
