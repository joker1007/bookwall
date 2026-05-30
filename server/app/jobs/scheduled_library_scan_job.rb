# frozen_string_literal: true

class ScheduledLibraryScanJob < ApplicationJob
  queue_as :default

  def perform
    return unless ScheduledTaskSetting.instance.daily_scan_enabled?

    Library.where(auto_scan_enabled: true).find_each do |library|
      ScanLibraryJob.perform_later(library.id)
    end
  end
end
