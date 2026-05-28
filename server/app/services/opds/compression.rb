# frozen_string_literal: true

require "zlib"
require "brotli"
require "zstd-ruby"

module Opds
  # Negotiates a Content-Encoding for OPDS feed bodies based on the request's
  # Accept-Encoding header. Only the text feeds use this; page images and
  # downloads (CBZ/EPUB/PDF) are already compressed.
  module Compression
    # Server preference, best first. Used to break ties when the client gives
    # equal q-values to multiple codecs.
    CODECS = %w[zstd br gzip deflate].freeze

    module_function

    # Returns [content_encoding, body]. content_encoding is nil when nothing
    # acceptable was offered, in which case body is the original data.
    def encode(data, accept_encoding)
      encoding = negotiate(accept_encoding)
      return [nil, data] unless encoding

      [encoding, compress(data, encoding)]
    end

    def negotiate(accept_encoding)
      return nil if accept_encoding.nil? || accept_encoding.strip.empty?

      accepted = parse(accept_encoding)
      best = nil
      best_q = 0.0
      CODECS.each do |codec|
        q = accepted.fetch(codec) { accepted["*"] }
        next if q.nil? || q <= 0
        # Strict > keeps the server-preferred codec on ties (CODECS order).
        if q > best_q
          best = codec
          best_q = q
        end
      end
      best
    end

    def compress(data, encoding)
      case encoding
      when "gzip" then Zlib.gzip(data)
      # Zlib-wrapped deflate (RFC 1950), the form HTTP clients expect for the
      # "deflate" content coding.
      when "deflate" then Zlib::Deflate.deflate(data)
      when "br" then Brotli.deflate(data)
      when "zstd" then Zstd.compress(data)
      end
    end

    # Parses "gzip, br;q=0.5, *;q=0" into {"gzip" => 1.0, "br" => 0.5, "*" => 0.0}.
    def parse(header)
      header.split(",").each_with_object({}) do |part, acc|
        token, *params = part.strip.split(";")
        token = token.to_s.strip.downcase
        next if token.empty?

        name = canonical(token)
        next unless name

        acc[name] = quality(params)
      end
    end

    def quality(params)
      params.each do |param|
        key, value = param.strip.split("=", 2)
        return value.to_f if key&.strip&.downcase == "q"
      end
      1.0
    end

    # Maps codec aliases to the identifiers used in CODECS, dropping ones we
    # do not support so they never win negotiation.
    def canonical(token)
      case token
      when "gzip", "x-gzip" then "gzip"
      when "deflate" then "deflate"
      when "br" then "br"
      when "zstd" then "zstd"
      when "*" then "*"
      end
    end
  end
end
