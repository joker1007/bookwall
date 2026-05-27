class ReadingProgressSerializer
  include Alba::Resource

  attributes :current_page, :last_read_at

  attribute :settings do |progress|
    progress.settings
  end
end
