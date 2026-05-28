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
          {title: "All Libraries", href: helpers.opds_libraries_path, rel: "subsection"},
          {title: "Series", href: helpers.opds_series_index_path, rel: "subsection"},
          {title: "Tags", href: helpers.opds_tags_index_path, rel: "subsection"}
        ]
      )
      render_navigation(xml)
    end

    def recent
      books = accessible_books.order(added_at: :desc).limit(100)
                  .includes(:authors, :tags)
                  .with_attached_cover
      render_acquisition_feed("Recent", "urn:bookwall:recent", view_context_helpers.opds_recent_path, books)
    end

    def favorites
      user = Current.user
      scope = Book.joins(:favorites).where(favorites: {user_id: user.id})
                  .where(library_id: accessible_library_ids)
      facets = build_facets(scope) { |filters| view_context_helpers.opds_favorites_path(filters) }
      books = facets.books.includes(:authors, :tags).with_attached_cover
      render_acquisition_feed(
        "Favorites", "urn:bookwall:favorites",
        view_context_helpers.opds_favorites_path(active_facet_params), books, facets: facets.links
      )
    end

    def libraries
      helpers = view_context_helpers
      entries = accessible_libraries.order(:name).map do |lib|
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
      lib = find_accessible_library!(params[:library_id])
      facets = build_facets(lib.books) do |filters|
        view_context_helpers.opds_library_path(filters.merge(library_id: lib.id))
      end
      books = facets.books.includes(:authors, :tags).with_attached_cover.order(:title)
      render_acquisition_feed(
        lib.name, "urn:bookwall:library:#{lib.id}",
        view_context_helpers.opds_library_path(active_facet_params.merge(library_id: lib.id)),
        books, facets: facets.links
      )
    end

    def series_index
      helpers = view_context_helpers
      entries = Series.where(library_id: accessible_library_ids).order(:name).map do |s|
        {
          title: s.name,
          href: helpers.opds_series_path(series_id: s.id),
          id: "urn:bookwall:series:#{s.id}"
        }
      end
      xml = Opds::FeedBuilder.navigation(
        title: "Series",
        id: "urn:bookwall:series",
        self_url: helpers.opds_series_index_path,
        entries: entries
      )
      render_navigation(xml)
    end

    def series_show
      series = Series.where(library_id: accessible_library_ids).find(params[:series_id])
      # Series in Bookwall are basically reading order: sort by volume,
      # then title to keep ties stable.
      books = series.books.includes(:authors, :tags).with_attached_cover.order(:volume, :title)
      render_acquisition_feed(series.name, "urn:bookwall:series:#{series.id}",
                              view_context_helpers.opds_series_path(series_id: series.id), books)
    end

    def tags_index
      helpers = view_context_helpers
      entries = Tag.accessible_by(Current.user).order(:name).map do |t|
        {
          title: t.name,
          href: helpers.opds_tag_path(tag_id: t.id),
          id: "urn:bookwall:tag:#{t.id}"
        }
      end
      xml = Opds::FeedBuilder.navigation(
        title: "Tags",
        id: "urn:bookwall:tags",
        self_url: helpers.opds_tags_index_path,
        entries: entries
      )
      render_navigation(xml)
    end

    def tag_show
      tag = Tag.accessible_by(Current.user).find(params[:tag_id])
      books = tag.books.where(library_id: accessible_library_ids)
                 .includes(:authors, :tags).with_attached_cover.order(:title)
      render_acquisition_feed(tag.name, "urn:bookwall:tag:#{tag.id}",
                              view_context_helpers.opds_tag_path(tag_id: tag.id), books)
    end

    private

    def view_context_helpers
      Rails.application.routes.url_helpers
    end

    # Builds an Opds::Facets for the given base scope. The block receives a
    # filters hash ({series_id:, tag_id:} with nils omitted) and returns the
    # feed path for that combination.
    def build_facets(scope, &path_for)
      Opds::Facets.new(
        scope: scope,
        series_id: params[:series_id],
        tag_id: params[:tag_id],
        url_builder: ->(series_id:, tag_id:) {
          path_for.call({series_id: series_id, tag_id: tag_id}.compact)
        }
      )
    end

    def active_facet_params
      {series_id: params[:series_id].presence, tag_id: params[:tag_id].presence}.compact
    end

    def render_acquisition_feed(title, id, self_url, books, facets: [])
      xml = Opds::FeedBuilder.acquisition(
        title: title, id: id, self_url: self_url, books: books,
        helpers: view_context_helpers, facets: facets
      )
      render_feed(xml)
    end
  end
end
