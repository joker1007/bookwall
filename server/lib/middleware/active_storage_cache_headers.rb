# frozen_string_literal: true

module Middleware
  # Active Storage proxy URLs are content-addressable (signed blob id + variation
  # digest), so caching is safe forever. Adds the `immutable` directive that Rails'
  # http_cache_forever omits, letting browsers skip the conditional-GET entirely.
  class ActiveStorageCacheHeaders
    PATH_PREFIX = "/rails/active_storage/"
    CACHE_CONTROL_VALUE = "private, max-age=31536000, immutable"
    CACHE_CONTROL_KEY = "cache-control"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if cache_eligible?(env, status)
        headers[CACHE_CONTROL_KEY] = CACHE_CONTROL_VALUE
      end
      [status, headers, body]
    end

    private

    def cache_eligible?(env, status)
      return false unless env["REQUEST_METHOD"] == "GET" || env["REQUEST_METHOD"] == "HEAD"
      return false unless env["PATH_INFO"]&.start_with?(PATH_PREFIX)
      # Skip 4xx/5xx: caching a 404 would pin missing images even after the blob returns.
      status == 200 || status == 206 || status == 302
    end
  end
end
