# frozen_string_literal: true

require "zlib"
require "brotli"
require "zstd-ruby"

module Opds
  module Compression
    # Server preference order, used to break ties on equal client q-values.
    CODECS = %w[zstd br gzip deflate].freeze

    module_function

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
      # zlib-wrapped (RFC 1950): the form HTTP clients expect for "deflate".
      when "deflate" then Zlib::Deflate.deflate(data)
      when "br" then Brotli.deflate(data)
      when "zstd" then Zstd.compress(data)
      end
    end

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
