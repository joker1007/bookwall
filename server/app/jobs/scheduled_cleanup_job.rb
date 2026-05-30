# frozen_string_literal: true

class ScheduledCleanupJob < ApplicationJob
  queue_as :default

  def perform
    return unless ScheduledTaskSetting.instance.cleanup_enabled?

    Cleanup::OrphanCleaner.new.call
  end
end
