# frozen_string_literal: true

require "pagy"

# Allow clients to request larger pages via `?limit=N`. The book list's
# infinite scroll fetches in large chunks, so cap high enough to serve a
# full chunk in one request. Higher values get silently capped.
Pagy::OPTIONS[:max_limit] = 1000
