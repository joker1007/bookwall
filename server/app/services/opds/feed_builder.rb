# frozen_string_literal: true

module Opds
  class FeedBuilder
    ATOM_NS = "http://www.w3.org/2005/Atom".freeze
    OPDS_NS = "http://opds-spec.org/2010/catalog".freeze
    PSE_NS = "http://vaemendis.net/opds-pse/ns".freeze
    # Atom Threading Extensions (RFC 4685): supplies thr:count, the per-facet
    # result count OPDS clients show next to each filter option.
    THREAD_NS = "http://purl.org/syndication/thread/1.0".freeze

    ACQUISITION_REL = "http://opds-spec.org/acquisition".freeze
    IMAGE_REL = "http://opds-spec.org/image".freeze
    THUMB_REL = "http://opds-spec.org/image/thumbnail".freeze
    PSE_STREAM_REL = "http://vaemendis.net/opds-pse/stream".freeze
    FACET_REL = "http://opds-spec.org/facet".freeze

    # OPDS-PSE clients (Chunky, Panels, KyBook, ...) substitute the literal
    # "{pageNumber}" token in the link href with a real page number. Rails
    # path helpers percent-encode `{` / `}` so we route the helper through a
    # URL-safe sentinel and swap it back to preserve the literal token.
    PSE_TEMPLATE_SENTINEL = "OPDSPSEPAGENUMBER".freeze
    PSE_TEMPLATE_TOKEN = "{pageNumber}".freeze

    # OPDS-PSE streams image pages, so EPUB (reflowable XHTML/HTML) is not a
    # valid PSE source. EPUBs are still discoverable via the regular OPDS
    # acquisition link and downloaded whole by the reader.
    PSE_STREAMABLE_FORMATS = %w[cbz pdf image_dir].freeze

    # Served by Thruster / Rails static file server from server/public/opds/.
    # Used when a book has no Active Storage cover attached so OPDS readers
    # always have an image to render instead of a broken-link icon.
    PLACEHOLDER_COVER_PATH = "/opds/placeholder-cover.jpg".freeze
    PLACEHOLDER_THUMB_PATH = "/opds/placeholder-thumb.jpg".freeze

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

    def self.acquisition(title:, id:, self_url:, books:, helpers:, facets: [])
      build_feed do |xml|
        xml.title title
        xml.id_ id
        xml.updated Time.current.iso8601
        xml.link(rel: "self", href: self_url, type: Opds::ACQUISITION_MIME)

        facets.each { |facet| facet_link(xml, facet) }

        books.each do |book|
          xml.entry do
            xml.title book.title
            xml.id_ "urn:bookwall:book:#{book.id}"
            xml.updated book.updated_at.iso8601
            book.authors.each { |a| xml.author { xml.name a.name } }
            xml["dc"].language(book_language(book)) if book_language(book)
            # Spec-correct format identification is the acquisition link's
            # @type attribute, but some OPDS clients additionally inspect
            # dc:format and atom:content. Emitting both keeps EPUB recognition
            # working when other metadata (authors / series / pages) is sparse.
            xml["dc"].format_(download_mime(book))
            book.tags.each { |t| xml.category(term: t.name) }
            content_text = entry_content(book)
            xml.content_(type: "text") { xml.text(content_text) } if content_text.present?

            xml.link(
              rel: ACQUISITION_REL,
              href: helpers.opds_book_file_path(book_id: book.id, format: acquisition_format(book)),
              type: download_mime(book)
            )

            if book.cover.attached?
              xml.link(rel: IMAGE_REL, href: helpers.rails_blob_path(book.cover, only_path: true), type: book.cover.content_type)
              if (variant = thumb_variant(book))
                xml.link(rel: THUMB_REL, href: helpers.rails_representation_path(variant, only_path: true), type: "image/jpeg")
              end
            else
              xml.link(rel: IMAGE_REL, href: PLACEHOLDER_COVER_PATH, type: "image/jpeg")
              xml.link(rel: THUMB_REL, href: PLACEHOLDER_THUMB_PATH, type: "image/jpeg")
            end

            if pse_streamable?(book) && book.page_count.to_i > 0
              xml.send(:"pse:link",
                       rel: PSE_STREAM_REL,
                       href: pse_stream_href(book, helpers),
                       type: "image/jpeg",
                       "pse:count" => book.page_count)
            end
          end
        end
      end
    end

    def self.build_feed
      doc = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.feed("xmlns" => ATOM_NS, "xmlns:opds" => OPDS_NS, "xmlns:pse" => PSE_NS, "xmlns:dc" => "http://purl.org/dc/elements/1.1/", "xmlns:thr" => THREAD_NS) do
          yield xml
        end
      end
      doc.to_xml
    end

    def self.facet_link(xml, facet)
      attrs = {
        rel: FACET_REL,
        href: facet.href,
        title: facet.title,
        "opds:facetGroup" => facet.group,
        "thr:count" => facet.count
      }
      attrs["opds:activeFacet"] = "true" if facet.active
      xml.link(attrs)
    end

    def self.pse_streamable?(book)
      PSE_STREAMABLE_FORMATS.include?(book.file_format.to_s)
    end

    # image_dir books are exposed to OPDS clients as CBZ: the acquisition
    # link points at /file.cbz, the controller builds the archive on the fly
    # from the directory of images, and the response is discarded after send.
    def self.acquisition_format(book)
      case book.file_format.to_s
      when "image_dir" then "cbz"
      else book.file_format.to_s
      end
    end

    def self.pse_stream_href(book, helpers)
      helpers.opds_book_page_path(book_id: book.id, n: PSE_TEMPLATE_SENTINEL)
             .sub(PSE_TEMPLATE_SENTINEL, PSE_TEMPLATE_TOKEN)
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
      when "cbz", "image_dir" then "application/x-cbz"
      when "epub" then "application/epub+zip"
      when "pdf" then "application/pdf"
      else "application/octet-stream"
      end
    end

    # Human-readable summary string embedded in <atom:content>. Format label
    # comes first so clients that scan the body for "EPUB" / "CBZ" / "PDF" can
    # latch onto it even when title/authors are minimal.
    def self.entry_content(book)
      parts = []
      parts << format_label(book)
      parts << "#{book.page_count} pages" if book.page_count.to_i.positive?
      parts << format_file_size(book.file_size) if book.file_size.to_i.positive?
      parts.compact.join(" · ")
    end

    def self.format_label(book)
      case book.file_format.to_s
      when "cbz", "image_dir" then "CBZ"
      when "epub" then "EPUB"
      when "pdf" then "PDF"
      end
    end

    def self.format_file_size(bytes)
      return nil unless bytes&.positive?
      units = %w[B KB MB GB TB]
      value = bytes.to_f
      unit_index = 0
      while value >= 1024 && unit_index < units.length - 1
        value /= 1024
        unit_index += 1
      end
      "#{value < 10 && unit_index.positive? ? format("%.1f", value) : value.to_i} #{units[unit_index]}"
    end
  end
end
