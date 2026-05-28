# frozen_string_literal: true

module Middleware
  # Force every `text/html` response to revalidate against the server.
  #
  # Bookwall ships a single-page Vite build into `public/ui/`. Vite hashes
  # the JS / CSS bundles into `/ui/assets/<name>-<hash>.<ext>`, so those
  # files can sit on `Cache-Control: public, max-age=31536000, immutable`
  # (set via `config.public_file_server.headers` in production) — they're
  # safe to cache for a year. The SPA shell (`public/ui/index.html` and
  # the SpaController fallback at `/ui/*`) is NOT hashed though, so the
  # default 1-year header would pin a stale shell that references
  # deleted asset hashes after a deploy.
  #
  # Returning `no-cache` (not `no-store`) lets the browser keep the HTML
  # in its cache and only revalidate via ETag / 304, which is cheap and
  # what we want for a snappy reload.
  class SpaCacheHeaders
    HTML_CONTENT_TYPE = %r{\Atext/html\b}i
    REPLACEMENT = "no-cache"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers[CACHE_CONTROL_KEY] = REPLACEMENT if html_response?(headers)
      [status, headers, body]
    end

    private

    CACHE_CONTROL_KEY = "cache-control"

    def html_response?(headers)
      # Rack 3 normalises header names to lowercase, but the Hash itself
      # is case-sensitive. Probe both forms so a downstream middleware
      # that wrote `Content-Type` still gets picked up.
      ct = headers[CONTENT_TYPE_KEY_LOWER] || headers[CONTENT_TYPE_KEY_TITLE]
      ct.is_a?(String) && ct.match?(HTML_CONTENT_TYPE)
    end

    CONTENT_TYPE_KEY_LOWER = "content-type"
    CONTENT_TYPE_KEY_TITLE = "Content-Type"
  end
end
