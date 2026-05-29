# frozen_string_literal: true

# Application-wide on/off switches for the recurring background tasks.
# A single row holds the global state; the recurring jobs fire on schedule
# regardless and consult this row at runtime to decide whether to act.
class ScheduledTaskSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
