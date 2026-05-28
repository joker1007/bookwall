# frozen_string_literal: true

class UserSerializer
  include Alba::Resource

  attributes :id, :email_address
end
