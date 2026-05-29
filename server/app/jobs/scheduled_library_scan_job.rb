# frozen_string_literal: true

# Fired daily by SolidQueue. Enqueues a scan for every library that opts in,
# but only while the global daily-scan switch is on. The actual scanning is
# delegated to the existing ScanLibraryJob so each library runs independently.
class ScheduledLibraryScanJob < ApplicationJob
  queue_as :default

  def perform
    return unless ScheduledTaskSetting.instance.daily_scan_enabled?

    Library.where(auto_scan_enabled: true).find_each do |library|
      ScanLibraryJob.perform_later(library.id)
    end
  end
end
