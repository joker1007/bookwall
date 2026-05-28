# frozen_string_literal: true

module Api
  class UsersController < BaseController
    # Directory of users for the library share picker. Authenticated-only and
    # intentionally exposes id + email_address only (no password digest).
    def index
      users = User.order(:email_address)
      render json: {users: UserSerializer.new(users).serializable_hash}
    end
  end
end
