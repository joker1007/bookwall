# frozen_string_literal: true

class ScanLibraryJob < ApplicationJob
  queue_as :default

  def perform(library_id, scan_log_id = nil)
    library = Library.find(library_id)
    scan_log = library.scan_logs.find_by(id: scan_log_id) if scan_log_id
    Scanners::LibraryScanner.new(library, scan_log: scan_log).call
  end
end
