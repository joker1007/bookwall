# frozen_string_literal: true

module Opds
  class FeedBuilder
    ATOM_NS = "http://www.w3.org/2005/Atom"
    OPDS_NS = "http://opds-spec.org/2010/catalog"
    PSE_NS = "http://vaemendis.net/opds-pse/ns"
    # Atom Threading (RFC 4685): supplies thr:count, the per-facet result count.
    THREAD_NS = "http://purl.org/syndication/thread/1.0"

    ACQUISITION_REL = "http://opds-spec.org/acquisition"
    IMAGE_REL = "http://opds-spec.org/image"
    THUMB_REL = "http://opds-spec.org/image/thumbnail"
    PSE_STREAM_REL = "http://vaemendis.net/opds-pse/stream"
    FACET_REL = "http://opds-spec.org/facet"
    # Bookwall-specific capability advertised on the root feed so first-party
    # clients can detect a Bookwall server and learn the progress-sync endpoint.
    PROGRESS_SYNC_REL = "https://bookwall.joker1007.net/rel/progress-sync"

    # Rails path helpers percent-encode `{`/`}`, so route through a URL-safe
    # sentinel and swap it back to keep the literal "{pageNumber}" PSE token.
    PSE_TEMPLATE_SENTINEL = "OPDSPSEPAGENUMBER"
    PSE_TEMPLATE_TOKEN = "{pageNumber}"
    # Same sentinel trick for the progress-sync template's "{bookId}" token.
    BOOK_ID_SENTINEL = "OPDSBOOKID"
    BOOK_ID_TOKEN = "{bookId}"

    # PSE streams image pages, so reflowable EPUB is not a valid PSE source.
    PSE_STREAMABLE_FORMATS = %w[cbz pdf image_dir].freeze

    def self.navigation(title:, id:, self_url:, entries:, links: [])
      build_feed do |xml|
        xml.title title
        xml.id_ id
        xml.updated Time.current.iso8601
        xml.link(rel: "self", href: self_url, type: Opds::NAVIGATION_MIME)
        xml.link(rel: "start", href: entries.first&.dig(:href) || self_url, type: Opds::NAVIGATION_MIME)
        links.each { |link| xml.link(link) }
        entries.each do |entry|
          xml.entry do
            xml.title entry[:title]
            xml.id_ entry[:id] || "urn:bookwall:nav:#{entry[:title]}"
            xml.updated Time.current.iso8601
            xml.link(rel: entry[:rel] || "subsection", href: entry[:href], type: entry[:type] || Opds::ACQUISITION_MIME)
            xml.content_(type: "text") { xml.text(entry[:summary]) } if entry[:summary]
            # Non-standard but uses the standard image rels: a representative cover
            # (e.g. a series' first volume) so clients can show a navigation thumbnail.
            xml.link(rel: IMAGE_REL, href: entry[:image_href], type: "image/jpeg") if entry[:image_href]
            xml.link(rel: THUMB_REL, href: entry[:thumb_href], type: "image/jpeg") if entry[:thumb_href]
          end
        end
      end
    end

    # Image/thumbnail hrefs for a representative [book] (nil -> placeholder), for
    # decorating navigation entries. Mirrors the acquisition feed's cover links.
    def self.cover_hrefs(book, helpers)
      return {image_href: CoverPlaceholder::COVER_PATH, thumb_href: CoverPlaceholder::THUMB_PATH} unless book&.cover&.attached?

      image = helpers.rails_blob_path(book.cover, only_path: true)
      variant = thumb_variant(book)
      thumb = variant ? helpers.rails_representation_path(variant, only_path: true) : image
      {image_href: image, thumb_href: thumb}
    end

    def self.acquisition(title:, id:, self_url:, books:, helpers:, facets: [], reading_progress_by_book_id: {})
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
            # Atom published = library registration time, used by clients to sort by added date.
            xml.published book.added_at.iso8601 if book.added_at
            book.authors.each { |a| xml.author { xml.name a.name } }
            xml["dc"].language(book_language(book)) if book_language(book)
            # Some OPDS clients inspect dc:format/atom:content for format, not just the link @type.
            xml["dc"].format_(download_mime(book))
            book.tags.each { |t| xml.category(term: t.name) }
            content_text = entry_content(book)
            xml.content_(type: "text") { xml.text(content_text) } if content_text.present?

            acquisition_attrs = {
              rel: ACQUISITION_REL,
              href: helpers.opds_book_file_path(book_id: book.id, format: acquisition_format(book)),
              type: download_mime(book)
            }
            # image_dir is repackaged as CBZ on the fly, so length is only an estimate there.
            acquisition_attrs[:length] = book.file_size if book.file_size.to_i.positive?
            xml.link(acquisition_attrs)

            if book.cover.attached?
              xml.link(rel: IMAGE_REL, href: helpers.rails_blob_path(book.cover, only_path: true), type: book.cover.content_type)
              if (variant = thumb_variant(book))
                xml.link(rel: THUMB_REL, href: helpers.rails_representation_path(variant, only_path: true), type: "image/jpeg")
              end
            else
              xml.link(rel: IMAGE_REL, href: CoverPlaceholder::COVER_PATH, type: "image/jpeg")
              xml.link(rel: THUMB_REL, href: CoverPlaceholder::THUMB_PATH, type: "image/jpeg")
            end

            if pse_streamable?(book) && book.page_count.to_i > 0
              xml.send(:"pse:link", pse_link_attrs(book, helpers, reading_progress_by_book_id[book.id]))
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

    # image_dir books are exposed as CBZ; the controller builds the archive on the fly.
    def self.acquisition_format(book)
      case book.file_format.to_s
      when "image_dir" then "cbz"
      else book.file_format.to_s
      end
    end

    def self.progress_sync_link(helpers)
      href = helpers.opds_book_progress_path(book_id: BOOK_ID_SENTINEL).sub(BOOK_ID_SENTINEL, BOOK_ID_TOKEN)
      {rel: PROGRESS_SYNC_REL, href: href, type: "application/json"}
    end

    def self.pse_stream_href(book, helpers)
      helpers.opds_book_page_path(book_id: book.id, n: PSE_TEMPLATE_SENTINEL)
             .sub(PSE_TEMPLATE_SENTINEL, PSE_TEMPLATE_TOKEN)
    end

    # pse:lastRead is 1-based per spec while current_page is 0-based, hence +1 (clamped).
    def self.pse_link_attrs(book, helpers, progress)
      attrs = {
        rel: PSE_STREAM_REL,
        href: pse_stream_href(book, helpers),
        type: "image/jpeg",
        "pse:count" => book.page_count
      }
      if progress
        attrs["pse:lastRead"] = [progress.current_page + 1, book.page_count].min
        attrs["pse:lastReadDate"] = progress.last_read_at.utc.iso8601 if progress.last_read_at
      end
      attrs
    end

    def self.thumb_variant(book)
      book.cover.variant(:thumb)
    rescue StandardError
      nil
    end

    def self.book_language(book)
      # Placeholder: no language column on books yet.
      nil
    end

    def self.download_mime(book)
      Books::FileFormat.mime(book.file_format)
    end

    # Format label first so clients scanning the body for "EPUB"/"CBZ"/"PDF" still match.
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
