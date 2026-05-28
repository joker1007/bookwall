# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Users", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  describe "GET /api/users" do
    it "requires authentication" do
      get "/api/users"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists users with id and email only, never the password digest" do
      other = create(:user, email_address: "other@example.com")
      sign_in!

      get "/api/users"

      expect(response).to have_http_status(:ok)
      users = response.parsed_body["users"]
      ids = users.map { |u| u["id"] }
      expect(ids).to include(user.id, other.id)
      expect(users.first.keys).to contain_exactly("id", "email_address")
    end
  end
end
