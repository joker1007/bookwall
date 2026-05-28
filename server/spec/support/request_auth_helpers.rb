# frozen_string_literal: true

# Shared login helpers for request specs. Centralizes the session-cookie and
# HTTP Basic auth setup that previously lived (duplicated) in each spec.
module RequestAuthHelpers
  # The password the :user factory assigns by default.
  TEST_PASSWORD = "password123"

  # Logs in via the session endpoint. Defaults to the `user` let so the common
  # single-user case stays terse; pass an account for multi-user specs.
  def sign_in!(account = user, password: TEST_PASSWORD)
    post "/api/session",
      params: {email_address: account.email_address, password: password},
      as: :json
  end

  # HTTP Basic credentials header for the OPDS endpoints.
  def basic_auth_header(account = user, password: TEST_PASSWORD)
    ActionController::HttpAuthentication::Basic.encode_credentials(account.email_address, password)
  end
end
