# frozen_string_literal: true

module Middleware
  # The Vite SPA shell (index.html) is unhashed, so it must revalidate or a
  # deploy pins a stale shell referencing deleted asset hashes. no-cache (not
  # no-store) keeps it cacheable via ETag/304.
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
      # Probe both cases: the headers Hash is case-sensitive despite Rack 3 normalising names.
      ct = headers[CONTENT_TYPE_KEY_LOWER] || headers[CONTENT_TYPE_KEY_TITLE]
      ct.is_a?(String) && ct.match?(HTML_CONTENT_TYPE)
    end

    CONTENT_TYPE_KEY_LOWER = "content-type"
    CONTENT_TYPE_KEY_TITLE = "Content-Type"
  end
end
