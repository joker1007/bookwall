# frozen_string_literal: true

require "zip"

module Parsers
  class CbzParser < BaseParser
    COMIC_INFO_FILENAME = "ComicInfo.xml".freeze

    def metadata
      @metadata ||= build_metadata
    end

    def page_count
      image_entry_names.size
    end

    def cover_bytes
      raise CoverNotFound, @path if image_entry_names.empty?
      read_entry(image_entry_names.first)
    end

    def page_bytes(index)
      name = image_entry_names.fetch(index)
      read_entry(name)
    rescue IndexError
      raise Error, "page index out of range: #{index}"
    end

    def page_content_type(index)
      name = image_entry_names.fetch(index)
      Parsers.mime_type_for_extension(name, default: "image/jpeg")
    rescue IndexError
      "image/jpeg"
    end

    private

    def build_metadata
      base = {
        title: basename_without_ext,
        series: parent_dirname,
        volume: nil,
        authors: [],
        tags: [],
        published_at: nil,
        page_count: image_entry_names.size
      }
      merge_comic_info(base)
    rescue Zip::Error => e
      raise InvalidFile, "broken CBZ: #{e.message}"
    end

    def merge_comic_info(base)
      xml = read_comic_info
      return base unless xml

      doc = Nokogiri::XML(xml)
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

    def read_comic_info
      Zip::File.open(@path) do |zip|
        entry = zip.find { |e| e.name.end_with?(COMIC_INFO_FILENAME) }
        entry&.get_input_stream&.read
      end
    rescue Zip::Error => e
      raise InvalidFile, "broken CBZ: #{e.message}"
    end

    def image_entry_names
      @image_entry_names ||= Zip::File.open(@path) do |zip|
        zip.entries
          .reject(&:directory?)
          .select { |e| IMAGE_EXTENSIONS.include?(File.extname(e.name).downcase) }
          .sort_by { |e| e.name.downcase }
          .map(&:name)
      end
    rescue Zip::Error => e
      raise InvalidFile, "broken CBZ: #{e.message}"
    end

    def read_entry(name)
      Zip::File.open(@path) do |zip|
        zip.get_input_stream(name).read
      end
    end
  end
end
