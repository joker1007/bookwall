# frozen_string_literal: true

# Per-library visibility enforcement shared by the API and OPDS controllers.
# Every browsable record (Book/Series/Tag/Author) is reachable only through
# books.library_id, so all visibility collapses to "which library ids can the
# current user see". A user can see a library they own or have been shared.
#
# Not-permitted access returns 404 (don't leak existence) via scoped finders
# that raise ActiveRecord::RecordNotFound. Management of a visible-but-not-owned
# library returns 403 (ManagementForbidden) — the shared user already knows it
# exists, so there is nothing to leak.
module LibraryScoping
  extend ActiveSupport::Concern

  class ManagementForbidden < StandardError; end

  included do
    rescue_from ManagementForbidden do
      render json: {error: "forbidden"}, status: :forbidden
    end
  end

  private

  # Memoized per request: the single source of truth for visibility.
  def accessible_library_ids
    @accessible_library_ids ||= Library.accessible_by(Current.user).pluck(:id)
  end

  def owned_library_ids
    @owned_library_ids ||= Library.owned_by(Current.user).pluck(:id)
  end

  def accessible_libraries
    Library.where(id: accessible_library_ids)
  end

  def accessible_books
    Book.where(library_id: accessible_library_ids)
  end

  # 404 when the library is not visible to the current user.
  def find_accessible_library!(id)
    accessible_libraries.find(id)
  end

  # 404 when the book is not visible to the current user.
  def find_accessible_book!(id)
    accessible_books.find(id)
  end

  # Management actions (edit/scan/delete/share): owner only. Stranger -> 404,
  # shared (non-owner) user -> 403.
  def find_owned_library!(id)
    library = find_accessible_library!(id)
    raise ManagementForbidden unless library.can_manage?(Current.user)
    library
  end
end
