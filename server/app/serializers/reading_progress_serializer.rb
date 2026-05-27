# frozen_string_literal: true

class ReadingProgressSerializer
  include Alba::Resource

  attributes :current_page, :last_read_at, :epub_cfi, :progress_fraction

  attribute :settings do |progress|
    progress.settings
  end
end
