require "hexapdf"
require "open3"
require "tempfile"

module Parsers
  class PdfParser < BaseParser
    RASTERIZE_DPI = 150

    def metadata
      @metadata ||= build_metadata
    end

    def page_count
      with_document { |d| d.pages.count }
    end

    def cover_bytes
      rasterize_page(1)
    end

    def page_bytes(index)
      rasterize_page(index + 1)
    end

    private

    def with_document(&block)
      HexaPDF::Document.open(@path, &block)
    rescue HexaPDF::Error => e
      raise InvalidFile, "broken PDF: #{e.message}"
    end

    def build_metadata
      with_document do |doc|
        info = doc.trailer.info
        title = info[:Title].to_s
        author = info[:Author].to_s

        {
          title: title.presence || basename_without_ext,
          series: nil,
          volume: nil,
          authors: author.empty? ? [] : [author],
          tags: [],
          published_at: parse_pdf_date(info[:CreationDate]),
          page_count: doc.pages.count
        }
      end
    end

    def parse_pdf_date(raw)
      return nil if raw.nil? || raw.to_s.empty?
      str = raw.to_s.sub(/\AD:/, "")
      Date.strptime(str[0, 8], "%Y%m%d")
    rescue ArgumentError
      nil
    end

    def rasterize_page(page_num)
      raise Error, "invalid page number: #{page_num}" if page_num < 1
      tmpdir = Dir.mktmpdir("bookwall-pdf-")
      prefix = File.join(tmpdir, "page")
      cmd = [
        "pdftocairo", "-jpeg", "-singlefile",
        "-f", page_num.to_s, "-l", page_num.to_s,
        "-r", RASTERIZE_DPI.to_s,
        @path, prefix
      ]
      _, stderr, status = Open3.capture3(*cmd)
      raise CoverNotFound, "pdftocairo failed: #{stderr.strip}" unless status.success?
      File.binread("#{prefix}.jpg")
    ensure
      FileUtils.remove_entry(tmpdir) if tmpdir && File.directory?(tmpdir)
    end
  end
end
