# frozen_string_literal: true

require "gepub"

module Parsers
  class EpubParser < BaseParser
    def metadata
      @metadata ||= build_metadata
    end

    def page_count
      book.spine.itemref_list.size
    end

    def cover_bytes
      item = cover_item
      raise CoverNotFound, @path unless item
      item.content
    end

    def page_bytes(index)
      idref = book.spine.itemref_list.fetch(index).idref
      item = book.items[idref] || raise(Error, "missing manifest item: #{idref}")
      item.content
    rescue IndexError
      raise Error, "spine index out of range: #{index}"
    end

    def page_progression_direction
      book.spine.page_progression_direction
    end

    def language
      book.language.to_s.presence
    end

    private

    def book
      @book ||= GEPUB::Book.parse(@path)
    rescue StandardError => e
      raise InvalidFile, "broken EPUB: #{e.message}"
    end

    def build_metadata
      {
        title: title_text.presence || basename_without_ext,
        series: calibre_meta_value("calibre:series"),
        volume: parse_series_index(calibre_meta_value("calibre:series_index")),
        authors: creator_names,
        tags: subjects,
        published_at: publication_date,
        page_count: page_count
      }
    end

    def subjects
      list = book.subject_list rescue []
      list.map { |meta| meta.content.to_s.strip }.reject(&:empty?).uniq
    end

    # Calibre stores series info as OPF2 oldstyle meta; value is in content= attr, not element text.
    def calibre_meta_value(name)
      metadata = book.metadata rescue nil
      entries = metadata&.oldstyle_meta || []
      meta = entries.find { |m| m["name"].to_s == name }
      meta&.[]("content").to_s.strip.presence
    end

    # Calibre writes the index as "1.0" / "2.5"; volume is an integer column.
    def parse_series_index(raw)
      return nil if raw.blank?
      n = Float(raw, exception: false)&.to_i
      n if n&.positive?
    end

    def title_text
      book.title.to_s
    end

    def creator_names
      list = book.creator_list rescue nil
      if list && !list.empty?
        list.map { |meta| meta.content.to_s.strip }.reject(&:empty?)
      else
        [book.creator.to_s.strip].reject(&:empty?)
      end
    end

    def publication_date
      meta = book.date rescue nil
      raw = meta.respond_to?(:content) ? meta.content : meta
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end

    def cover_item
      explicit = book.cover_image rescue nil
      return explicit if explicit
      first_image_item
    end

    def first_image_item
      book.items.values.find { |i| i.media_type.to_s.start_with?("image/") }
    end
  end
end
