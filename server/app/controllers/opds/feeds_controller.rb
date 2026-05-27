# frozen_string_literal: true

module Opds
  class FeedsController < BaseController
    def root
      helpers = view_context_helpers
      xml = Opds::FeedBuilder.navigation(
        title: "Bookwall",
        id: "urn:bookwall:root",
        self_url: helpers.opds_root_path,
        entries: [
          {title: "Recent", href: helpers.opds_recent_path, rel: "http://opds-spec.org/sort/new"},
          {title: "Favorites", href: helpers.opds_favorites_path, rel: "subsection"},
          {title: "All Libraries", href: helpers.opds_libraries_path, rel: "subsection"}
        ]
      )
      render_navigation(xml)
    end

    def recent
      books = Book.order(added_at: :desc).limit(100)
                  .includes(:authors, :tags)
                  .with_attached_cover
      render_acquisition_feed("Recent", "urn:bookwall:recent", view_context_helpers.opds_recent_path, books)
    end

    def favorites
      user = Current.user
      books = Book.joins(:favorites).where(favorites: {user_id: user.id})
                  .includes(:authors, :tags)
                  .with_attached_cover
      render_acquisition_feed("Favorites", "urn:bookwall:favorites", view_context_helpers.opds_favorites_path, books)
    end

    def libraries
      helpers = view_context_helpers
      entries = Library.order(:name).map do |lib|
        {title: lib.name, href: helpers.opds_library_path(library_id: lib.id), id: "urn:bookwall:library:#{lib.id}"}
      end
      xml = Opds::FeedBuilder.navigation(
        title: "Libraries",
        id: "urn:bookwall:libraries",
        self_url: helpers.opds_libraries_path,
        entries: entries
      )
      render_navigation(xml)
    end

    def library
      lib = Library.find(params[:library_id])
      books = lib.books.includes(:authors, :tags).with_attached_cover.order(:title)
      render_acquisition_feed(lib.name, "urn:bookwall:library:#{lib.id}",
                              view_context_helpers.opds_library_path(library_id: lib.id), books)
    end

    private

    def view_context_helpers
      Rails.application.routes.url_helpers
    end

    def render_acquisition_feed(title, id, self_url, books)
      xml = Opds::FeedBuilder.acquisition(
        title: title, id: id, self_url: self_url, books: books, helpers: view_context_helpers
      )
      render_feed(xml)
    end
  end
end
