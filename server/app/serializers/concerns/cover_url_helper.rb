# frozen_string_literal: true

module CoverUrlHelper
  module_function

  def cover_thumb_url(book)
    return nil unless book&.cover&.attached?
    Rails.application.routes.url_helpers
      .rails_representation_path(book.cover.variant(:thumb), only_path: true)
  rescue ActiveStorage::InvariableError
    # Some content types (e.g. SVG) cannot be resized into a variant.
    # Fall back to a placeholder image instead of breaking serialization.
    CoverPlaceholder::THUMB_PATH
  end
end
