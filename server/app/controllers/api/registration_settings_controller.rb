# frozen_string_literal: true

module Api
  class RegistrationSettingsController < BaseController
    allow_unauthenticated_access only: %i[show]

    def show
      render json: serialize(RegistrationSetting.instance)
    end

    def update
      setting = RegistrationSetting.instance
      setting.update!(setting_params)
      render json: serialize(setting)
    end

    private

    def setting_params
      params.permit(:public_registration_enabled)
    end

    def serialize(setting)
      {
        public_registration_enabled: setting.public_registration_enabled,
        registration_open: RegistrationSetting.registration_open?
      }
    end
  end
end
