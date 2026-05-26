class Current < ActiveSupport::CurrentAttributes
  attribute :session, :api_token

  def user
    session&.user || api_token&.user
  end
end
