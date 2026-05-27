# frozen_string_literal: true

class ReadingProgressSerializer
  include Alba::Resource

  attributes :current_page, :last_read_at, :epub_cfi

  attribute :settings do |progress|
    progress.settings
  end
end
