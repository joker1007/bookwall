# frozen_string_literal: true

class LibrarySerializer
  include Alba::Resource

  attributes :id, :name, :path, :last_scanned_at, :created_at, :updated_at, :owner_id, :auto_scan_enabled

  # Per-viewer flag: the current user manages (owns) this library.
  attribute :can_manage do |lib|
    lib.owner_id == params[:current_user_id]
  end

  # Only owners need the share list. For shared (read-only) viewers it is [].
  # The index passes a batched {library_id => [user_id, ...]} map to avoid N+1.
  attribute :shared_user_ids do |lib|
    next [] unless lib.owner_id == params[:current_user_id]
    map = params[:shared_user_ids_by_library]
    map ? map.fetch(lib.id, []) : lib.shared_users.ids
  end
end
