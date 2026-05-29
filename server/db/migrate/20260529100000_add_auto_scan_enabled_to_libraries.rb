# frozen_string_literal: true

class AddAutoScanEnabledToLibraries < ActiveRecord::Migration[8.1]
  def change
    add_column :libraries, :auto_scan_enabled, :boolean, null: false, default: true
  end
end
