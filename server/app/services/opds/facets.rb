# frozen_string_literal: true

module Opds
  class Facets
    SERIES_GROUP = "Series"
    TAGS_GROUP = "Tags"

    Facet = Data.define(:group, :title, :href, :count, :active)

    def initialize(scope:, series_id:, tag_id:, url_builder:)
      @scope = scope
      @series_id = series_id.presence&.to_i
      @tag_id = tag_id.presence&.to_i
      @url_builder = url_builder
    end

    def books
      relation = @scope
      relation = relation.where(series_id: @series_id) if @series_id
      # Subquery (not joins :tags) so the controller's includes(:tags) still eager-loads all tags.
      relation = relation.where(id: BookTag.where(tag_id: @tag_id).select(:book_id)) if @tag_id
      relation
    end

    def links
      series_facets + tag_facets
    end

    private

    def series_facets
      base = @tag_id ? @scope.where(id: BookTag.where(tag_id: @tag_id).select(:book_id)) : @scope
      counts = base.joins(:series).group("series.id", "series.name").count
      counts.map do |(id, name), count|
        Facet.new(
          group: SERIES_GROUP,
          title: name,
          href: @url_builder.call(series_id: id, tag_id: @tag_id),
          count: count,
          active: id == @series_id
        )
      end.sort_by { |facet| facet.title.to_s.downcase }
    end

    def tag_facets
      base = @series_id ? @scope.where(series_id: @series_id) : @scope
      counts = base.joins(:tags).group("tags.id", "tags.name").count
      counts.map do |(id, name), count|
        Facet.new(
          group: TAGS_GROUP,
          title: name,
          href: @url_builder.call(series_id: @series_id, tag_id: id),
          count: count,
          active: id == @tag_id
        )
      end.sort_by { |facet| facet.title.to_s.downcase }
    end
  end
end
