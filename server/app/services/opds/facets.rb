# frozen_string_literal: true

module Opds
  class Facets
    TAGS_GROUP = "Tags"

    Facet = Data.define(:group, :title, :href, :count, :active)

    def initialize(scope:, tag_id:, url_builder:)
      @scope = scope
      @tag_id = tag_id.presence&.to_i
      @url_builder = url_builder
    end

    def books
      return @scope unless @tag_id
      # Subquery (not joins :tags) so the controller's includes(:tags) still eager-loads all tags.
      @scope.where(id: BookTag.where(tag_id: @tag_id).select(:book_id))
    end

    def links
      tag_facets
    end

    private

    def tag_facets
      counts = @scope.joins(:tags).group("tags.id", "tags.name").count
      counts.map do |(id, name), count|
        Facet.new(
          group: TAGS_GROUP,
          title: name,
          href: @url_builder.call(tag_id: id),
          count: count,
          active: id == @tag_id
        )
      end.sort_by { |facet| facet.title.to_s.downcase }
    end
  end
end
