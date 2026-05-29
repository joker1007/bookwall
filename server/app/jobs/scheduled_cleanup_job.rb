# frozen_string_literal: true

# Fired daily by SolidQueue. Prunes orphaned metadata (books with missing
# files, then empty tags/authors) while the global cleanup switch is on.
class ScheduledCleanupJob < ApplicationJob
  queue_as :default

  def perform
    return unless ScheduledTaskSetting.instance.cleanup_enabled?

    Cleanup::OrphanCleaner.new.call
  end
end
