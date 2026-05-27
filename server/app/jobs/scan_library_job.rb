# frozen_string_literal: true

class ScanLibraryJob < ApplicationJob
  queue_as :default

  def perform(library_id)
    library = Library.find(library_id)
    Scanners::LibraryScanner.new(library).call
  end
end
