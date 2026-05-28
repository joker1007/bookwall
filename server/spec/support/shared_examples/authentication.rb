# frozen_string_literal: true

# Asserts an endpoint rejects unauthenticated callers. Usage:
#   it_behaves_like "requires authentication", :get, "/api/books"
RSpec.shared_examples "requires authentication" do |http_method, path|
  it "responds 401 without authentication" do
    public_send(http_method, path)
    expect(response).to have_http_status(:unauthorized)
  end
end
