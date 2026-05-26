class CreateScanLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :scan_logs do |t|
      t.references :library, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :status, null: false, default: 0
      t.integer :found_count, null: false, default: 0
      t.integer :added_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :removed_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end
  end
end
