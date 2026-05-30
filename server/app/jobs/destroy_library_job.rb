# frozen_string_literal: true

# Offloaded cascade destroy; record stays hidden via Library.not_deleting until done.
class DestroyLibraryJob < ApplicationJob
  queue_as :default

  def perform(library_id)
    library = Library.find_by(id: library_id)
    return unless library

    library.destroy!
  end
end
