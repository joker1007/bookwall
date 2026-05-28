# frozen_string_literal: true

# Shared setup for the OPDS feed request specs: an owning user, their HTTP
# Basic credentials header, and a library they own.
RSpec.shared_context "opds feed request" do
  let(:user) { create(:user) }
  let(:auth_header) { basic_auth_header }
  let(:library) { create(:library, owner: user) }
end
