class LibrarySerializer
  include Alba::Resource

  attributes :id, :name, :path, :last_scanned_at, :created_at, :updated_at
end
