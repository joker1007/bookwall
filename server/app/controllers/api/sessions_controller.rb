# frozen_string_literal: true

module Api
  class SessionsController < BaseController
    allow_unauthenticated_access only: %i[create]

    def show
      render json: serialize_user(Current.user)
    end

    def create
      user = User.authenticate_by(params.permit(:email_address, :password))
      if user
        start_new_session_for(user)
        render json: serialize_user(user), status: :created
      else
        render json: {error: "invalid_credentials"}, status: :unauthorized
      end
    end

    def destroy
      terminate_session
      head :no_content
    end

    private

    def serialize_user(user)
      {id: user.id, email_address: user.email_address}
    end
  end
end
