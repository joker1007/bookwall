# frozen_string_literal: true

class ScheduledTaskSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
