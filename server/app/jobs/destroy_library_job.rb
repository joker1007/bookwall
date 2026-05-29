# frozen_string_literal: true

# Cascading a library destroy through its books/series/scan_logs can be slow
# for large libraries, so the controller marks deleting_at and offloads the
# actual destroy here. The record stays hidden (see Library.not_deleting)
# until this finishes.
class DestroyLibraryJob < ApplicationJob
  queue_as :default

  def perform(library_id)
    library = Library.find_by(id: library_id)
    return unless library

    library.destroy!
  end
end
