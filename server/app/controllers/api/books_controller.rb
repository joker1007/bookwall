# frozen_string_literal: true

module Api
  class BooksController < BaseController
    EXTENSION_FOR_FORMAT = {
      "cbz" => ".cbz",
      "epub" => ".epub",
      "pdf" => ".pdf"
    }.freeze

    before_action :set_book, only: %i[show update destroy favorite unfavorite file]
    before_action :require_book_owner!, only: %i[update destroy]

    def index
      search = Books::Search.new(
        query: params[:q],
        library_id: params[:library_id],
        series_id: params[:series_id],
        author_id: params[:author_id],
        tag_id: params[:tag_id],
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
      return unless stale?(etag: etag)

      send_file resolved,
        type: Opds::FeedBuilder.download_mime(@book),
        disposition: "attachment",
        filename: download_filename(@book)
    end

    private

    def download_filename(book)
      ext = EXTENSION_FOR_FORMAT.fetch(book.file_format.to_s, "")
      raw = book.title.to_s.strip.presence || "book-#{book.id}"
      base = raw.gsub(/[\x00-\x1f\x7f"\/\\]/, "_")
      "#{base}#{ext}"
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

    def serialize_book(book)
      BookSerializer.new(
        book,
        params: {
          favorite_book_ids: favorite_book_ids([book.id]),
          reading_progress_by_book_id: reading_progress_by_book_id([book.id])
        }
      ).serializable_hash
    end

    def serialize_books(books)
      ids = books.map(&:id)
      BookSerializer.new(
        books,
        params: {
          favorite_book_ids: favorite_book_ids(ids),
          reading_progress_by_book_id: reading_progress_by_book_id(ids)
        }
      ).serializable_hash
    end

    def favorite_book_ids(book_ids)
      return [] if book_ids.empty?
      Favorite.where(user_id: Current.user.id, book_id: book_ids).pluck(:book_id)
    end

    def reading_progress_by_book_id(book_ids)
      return {} if book_ids.empty?
      ReadingProgress
        .where(user_id: Current.user.id, book_id: book_ids)
        .index_by(&:book_id)
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
