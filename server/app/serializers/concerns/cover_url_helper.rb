# frozen_string_literal: true

# Builds /covers/... URLs served by CoversController. signed_id and
# variation.key are pure MessageVerifier signatures, so no queries are
# issued beyond the with_attached_cover preload.
module CoverUrlHelper
  module_function

  def cover_url(book)
    return nil unless book&.cover&.attached?
    blob = book.cover.blob
    Rails.application.routes.url_helpers.cover_blob_path(blob.signed_id, blob.filename)
  end

  def cover_thumb_url(book)
    return nil unless book&.cover&.attached?
    variant = book.cover.variant(:thumb)
    Rails.application.routes.url_helpers.cover_thumb_path(
      variant.blob.signed_id, variant.variation.key, variant.blob.filename
    )
  rescue ActiveStorage::InvariableError
    CoverPlaceholder::THUMB_PATH
  end
end
