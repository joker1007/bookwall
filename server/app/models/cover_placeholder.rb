# frozen_string_literal: true

# Fallback when a book has no usable cover (no attachment, or a non-resizable type like SVG).
module CoverPlaceholder
  COVER_PATH = "/opds/placeholder-cover.jpg"
  THUMB_PATH = "/opds/placeholder-thumb.jpg"
end
