# frozen_string_literal: true

module Middleware
  # Pin a year-long, immutable Cache-Control onto every Active Storage
  # response.
  #
  # The app generates proxy-style URLs (see
  # `config.active_storage.resolve_model_to_route` in application.rb),
  # which carry only the stable signed blob id + variation digest in
  # the path. Every URL in the JSON payload therefore points at
  # content-addressable bytes — the URL only ever changes when the
  # bytes change — so it's safe to tell browsers to skip revalidation
  # for a year.
  #
  # Rails' own proxy controllers set `Cache-Control: public,
  # max-age=31536000` via `http_cache_forever`, but they don't add the
  # `immutable` directive. This middleware tightens that to
  # `private, max-age=31536000, immutable` so well-behaved browsers
  # skip the conditional-GET round trip entirely.
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
      # Cache successful serves (200, 206) and the signed redirect (302).
      # 4xx / 5xx are transient — caching a 404 here would pin missing
      # images even after the underlying blob is restored.
      status == 200 || status == 206 || status == 302
    end
  end
end
