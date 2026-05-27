# frozen_string_literal: true

module Books
  class Search
    SORTS = %w[title_asc title_desc added_at_asc added_at_desc series_asc].freeze

    def initialize(
      query: nil,
      library_id: nil,
      series_id: nil,
      author_id: nil,
      tag_id: nil,
      favorite_user_id: nil,
      sort: nil
    )
      @query = query.to_s.strip
      @library_id = library_id
      @series_id = series_id
      @author_id = author_id
      @tag_id = tag_id
      @favorite_user_id = favorite_user_id
      @sort = (sort || "added_at_desc").to_s
    end

    def relation
      scope = Book.all
      scope = apply_query(scope)
      scope = scope.where(library_id: @library_id) if @library_id.present?
      scope = scope.where(series_id: @series_id) if @series_id.present?
      scope = scope.joins(:authors).where(authors: {id: @author_id}) if @author_id.present?
      scope = scope.joins(:tags).where(tags: {id: @tag_id}) if @tag_id.present?
      if @favorite_user_id.present?
        scope = scope.joins(:favorites).where(favorites: {user_id: @favorite_user_id})
      end
      apply_sort(scope)
    end

    private

    def apply_query(scope)
      return scope if @query.empty?
      fts_match = ActiveRecord::Base.sanitize_sql_array(["books_fts MATCH ?", fts_query])
      scope.joins("JOIN books_fts ON books_fts.rowid = books.id AND #{fts_match}")
    rescue ActiveRecord::StatementInvalid
      # malformed FTS query — fall back to LIKE on title
      like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope.where("books.title LIKE ?", like)
    end

    def fts_query
      tokens = @query.split(/\s+/).reject(&:empty?).map { |t| t.gsub('"', "") }
      tokens.map { |t| "\"#{t}\"*" }.join(" ")
    end

    def apply_sort(scope)
      case @sort
      when "title_asc" then scope.order(:title)
      when "title_desc" then scope.order(title: :desc)
      when "added_at_asc" then scope.order(:added_at)
      when "series_asc" then scope.left_joins(:series).order(Arel.sql("series.name NULLS LAST"), :volume)
      else scope.order(added_at: :desc)
      end
    end
  end
end
