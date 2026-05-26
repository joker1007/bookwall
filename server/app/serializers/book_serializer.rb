class BookSerializer
  include Alba::Resource

  attributes :id, :title, :volume, :file_format, :file_path, :file_size,
             :file_hash, :page_count, :published_at, :added_at, :scanned_at,
             :library_id, :series_id

  attribute :series_name do |b|
    b.series&.name
  end

  attribute :authors do |b|
    b.authors.map { |a| {id: a.id, name: a.name} }
  end

  attribute :tags do |b|
    b.tags.map { |t| {id: t.id, name: t.name} }
  end

  attribute :cover do |b|
    next nil unless b.cover.attached?
    helpers = Rails.application.routes.url_helpers
    {
      url: helpers.rails_blob_path(b.cover, only_path: true),
      thumb_url: helpers.rails_representation_path(b.cover.variant(:thumb), only_path: true)
    }
  end
end
