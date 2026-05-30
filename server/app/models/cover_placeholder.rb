# frozen_string_literal: true

# Static placeholder image paths served from server/public/opds/ (and
# proxied to the client via /opds). Used as a fallback whenever a book has
# no usable cover image -- either no Active Storage attachment, or a cover
# whose content type cannot be resized into a variant (e.g. SVG).
module CoverPlaceholder
  COVER_PATH = "/opds/placeholder-cover.jpg"
  THUMB_PATH = "/opds/placeholder-thumb.jpg"
end
