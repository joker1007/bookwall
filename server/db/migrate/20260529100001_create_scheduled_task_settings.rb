# frozen_string_literal: true

class CreateScheduledTaskSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_task_settings do |t|
      t.boolean :daily_scan_enabled, null: false, default: true
      t.boolean :cleanup_enabled, null: false, default: true

      t.timestamps
    end
  end
end
