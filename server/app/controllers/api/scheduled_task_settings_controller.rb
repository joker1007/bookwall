# frozen_string_literal: true

module Api
  # Application-wide on/off switches for the recurring background tasks
  # (daily library scan, cleanup). A single shared row; any authenticated
  # user may read and toggle it.
  class ScheduledTaskSettingsController < BaseController
    def show
      render json: serialize(ScheduledTaskSetting.instance)
    end

    def update
      setting = ScheduledTaskSetting.instance
      setting.update!(setting_params)
      render json: serialize(setting)
    end

    private

    def setting_params
      params.permit(:daily_scan_enabled, :cleanup_enabled)
    end

    def serialize(setting)
      {
        daily_scan_enabled: setting.daily_scan_enabled,
        cleanup_enabled: setting.cleanup_enabled
      }
    end
  end
end
