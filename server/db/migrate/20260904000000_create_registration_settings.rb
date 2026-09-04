# frozen_string_literal: true

class CreateRegistrationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :registration_settings do |t|
      t.boolean :public_registration_enabled, null: false, default: false

      t.timestamps
    end
  end
end
