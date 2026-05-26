module Opds
  class FeedBuilder
    ATOM_NS = "http://www.w3.org/2005/Atom".freeze
    OPDS_NS = "http://opds-spec.org/2010/catalog".freeze
    PSE_NS = "http://vaemendis.net/opds-pse/ns".freeze

    ACQUISITION_REL = "http://opds-spec.org/acquisition".freeze
    IMAGE_REL = "http://opds-spec.org/image".freeze
    THUMB_REL = "http://opds-spec.org/image/thumbnail".freeze
    PSE_STREAM_REL = "http://vaemendis.net/opds-pse/stream".freeze

    def self.navigation(title:, id:, self_url:, entries:)
      build_feed do |xml|
        xml.title title
        xml.id_ id
        xml.updated Time.current.iso8601
        xml.link(rel: "self", href: self_url, type: Opds::NAVIGATION_MIME)
        xml.link(rel: "start", href: entries.first&.dig(:href) || self_url, type: Opds::NAVIGATION_MIME)
        entries.each do |entry|
          xml.entry do
            xml.title entry[:title]
            xml.id_ entry[:id] || "urn:bookwall:nav:#{entry[:title]}"
            xml.updated Time.current.iso8601
            xml.link(rel: entry[:rel] || "subsection", href: entry[:href], type: entry[:type] || Opds::ACQUISITION_MIME)
            xml.content_(type: "text") { xml.text(entry[:summary]) } if entry[:summary]
          end
        end
      end
    end

    def self.acquisition(title:, id:, self_url:, books:, helpers:)
      build_feed do |xml|
        xml.title title
        xml.id_ id
        xml.updated Time.current.iso8601
        xml.link(rel: "self", href: self_url, type: Opds::ACQUISITION_MIME)

        books.each do |book|
          xml.entry do
            xml.title book.title
            xml.id_ "urn:bookwall:book:#{book.id}"
            xml.updated book.updated_at.iso8601
            book.authors.each { |a| xml.author { xml.name a.name } }
            xml.dc_(:language, book_language(book)) if book_language(book)
            book.tags.each { |t| xml.category(term: t.name) }

            xml.link(
              rel: ACQUISITION_REL,
              href: helpers.opds_book_file_path(book),
              type: download_mime(book)
            )

            if book.cover.attached?
              xml.link(rel: IMAGE_REL, href: helpers.rails_blob_path(book.cover, only_path: true), type: book.cover.content_type)
              if (variant = thumb_variant(book))
                xml.link(rel: THUMB_REL, href: helpers.rails_representation_path(variant, only_path: true), type: "image/jpeg")
              end
            end

            if book.page_count.to_i > 0
              xml.send(:"pse:link",
                       rel: PSE_STREAM_REL,
                       href: helpers.opds_book_page_path(book_id: book.id, n: "{pageNumber}"),
                       type: "image/jpeg",
                       "pse:count" => book.page_count)
            end
          end
        end
      end
    end

    def self.build_feed
      doc = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.feed("xmlns" => ATOM_NS, "xmlns:opds" => OPDS_NS, "xmlns:pse" => PSE_NS, "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
          yield xml
        end
      end
      doc.to_xml
    end

    def self.thumb_variant(book)
      book.cover.variant(:thumb)
    rescue StandardError
      nil
    end

    def self.book_language(book)
      # Language extraction from EPUB metadata is best-effort; books table
      # does not yet have a language column, so this is a placeholder.
      nil
    end

    def self.download_mime(book)
      case book.file_format
      when "cbz" then "application/x-cbz"
      when "epub" then "application/epub+zip"
      when "pdf" then "application/pdf"
      else "application/octet-stream"
      end
    end
  end
end
