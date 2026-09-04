# frozen_string_literal: true

module Api
  class RegistrationsController < BaseController
    allow_unauthenticated_access only: %i[create]

    def create
      unless RegistrationSetting.registration_open?
        return render json: {error: "registration_closed"}, status: :forbidden
      end

      user = User.new(registration_params)
      if user.save
        start_new_session_for(user)
        render json: {id: user.id, email_address: user.email_address}, status: :created
      else
        render json: {errors: user.errors.full_messages}, status: :unprocessable_content
      end
    end

    private

    def registration_params
      params.permit(:email_address, :password, :password_confirmation)
    end
  end
end
