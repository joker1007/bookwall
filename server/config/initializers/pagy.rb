# frozen_string_literal: true

require "pagy"

# Allow clients to request larger pages via `?limit=N`. The UI's
# "items per page" selector exposes 20 / 50 / 100 / 200 — 200 is the
# ceiling so any higher value gets silently capped.
Pagy::OPTIONS[:max_limit] = 200
