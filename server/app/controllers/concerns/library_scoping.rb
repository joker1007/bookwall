# frozen_string_literal: true

# Invisible records 404 (don't leak existence); visible-but-not-owned management 403.
module LibraryScoping
  extend ActiveSupport::Concern

  class ManagementForbidden < StandardError; end

  included do
    rescue_from ManagementForbidden do
      render json: {error: "forbidden"}, status: :forbidden
    end
  end

  private

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

  def find_accessible_library!(id)
    accessible_libraries.find(id)
  end

  def find_accessible_book!(id)
    accessible_books.find(id)
  end

  def find_owned_library!(id)
    library = find_accessible_library!(id)
    raise ManagementForbidden unless library.can_manage?(Current.user)
    library
  end
end
