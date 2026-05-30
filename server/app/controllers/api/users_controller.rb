# frozen_string_literal: true

module Api
  class UsersController < BaseController
    def index
      users = User.order(:email_address)
      render json: {users: UserSerializer.new(users).serializable_hash}
    end
  end
end
