# frozen_string_literal: true

require "zip"

module Parsers
  class CbzParser < BaseParser
    COMIC_INFO_FILENAME = "ComicInfo.xml".freeze

    def metadata
      @metadata ||= build_metadata
    end

    def page_count
      load_once
      @image_entry_names.size
    end

    def cover_bytes
      load_once
      raise CoverNotFound, @path if @cover_bytes.nil?
      @cover_bytes
    end

    def page_bytes(index)
      load_once
      name = @image_entry_names.fetch(index)
      read_entry(name)
    rescue IndexError
      raise Error, "page index out of range: #{index}"
    end

    def page_content_type(index)
      load_once
      name = @image_entry_names.fetch(index)
      Parsers.mime_type_for_extension(name, default: "image/jpeg")
    rescue IndexError
      "image/jpeg"
    end

    private

    # The scanner's hot path is `metadata` then `cover_bytes`. Pulling
    # both pieces of state out in a single Zip::File.open avoids
    # parsing the central directory three times per book (once each
    # for image entries, ComicInfo.xml, and the cover image).
    def load_once
      return if @loaded
      Zip::File.open(@path) do |zip|
        image_entries = []
        info_entry = nil
        zip.each do |entry|
          next if entry.directory?
          if entry.name.end_with?(COMIC_INFO_FILENAME)
            info_entry = entry
          elsif IMAGE_EXTENSIONS.include?(File.extname(entry.name).downcase)
            image_entries << entry
          end
        end
        image_entries.sort_by! { |e| e.name.downcase }
        @image_entry_names = image_entries.map(&:name).freeze
        @cover_bytes = image_entries.first&.get_input_stream&.read
        @comic_info_xml = info_entry&.get_input_stream&.read
      end
      @loaded = true
    rescue Zip::Error => e
      raise InvalidFile, "broken CBZ: #{e.message}"
    end

    def build_metadata
      load_once
      base = {
        title: basename_without_ext,
        series: parent_dirname,
        volume: nil,
        authors: [],
        tags: [],
        published_at: nil,
        page_count: @image_entry_names.size
      }
      merge_comic_info(base)
    end

    def merge_comic_info(base)
      return base unless @comic_info_xml

      doc = Nokogiri::XML(@comic_info_xml)
      title = text_for(doc, "//Title")
      series = text_for(doc, "//Series")
      volume_raw = text_for(doc, "//Number")
      writer_raw = text_for(doc, "//Writer")
      tag_raw = text_for(doc, "//Tags")
      published_at = build_date(
        text_for(doc, "//Year"),
        text_for(doc, "//Month"),
        text_for(doc, "//Day")
      )

      base.merge(
        title: title.presence || base[:title],
        series: series.presence || base[:series],
        volume: volume_raw.present? ? volume_raw.to_i : nil,
        authors: split_csv(writer_raw),
        tags: split_csv(tag_raw),
        published_at: published_at
      )
    end

    def text_for(doc, xpath)
      doc.at_xpath(xpath)&.text
    end

    def split_csv(raw)
      raw.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def build_date(year, month, day)
      return nil if year.blank?
      Date.new(year.to_i, (month.presence || 1).to_i, (day.presence || 1).to_i)
    rescue ArgumentError
      nil
    end

    def read_entry(name)
      Zip::File.open(@path) do |zip|
        zip.get_input_stream(name).read
      end
    end
  end
end
