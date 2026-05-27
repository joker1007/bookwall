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

    # exposed for spec convenience
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
        series: nil,
        volume: nil,
        authors: creator_names,
        tags: [],
        published_at: publication_date,
        page_count: page_count
      }
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
