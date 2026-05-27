# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Tags", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  before do
    post "/api/session",
         params: {email_address: user.email_address, password: password},
         as: :json
  end

  describe "GET /api/tags" do
    it "lists tags" do
      create_list(:tag, 2)
      get "/api/tags"
      expect(response.parsed_body["tags"].size).to eq(2)
    end
  end

  describe "PATCH /api/tags/:id" do
    it "renames a tag" do
      tag = create(:tag, name: "old")
      patch "/api/tags/#{tag.id}", params: {name: "new"}, as: :json
      expect(tag.reload.name).to eq("new")
    end
  end

  describe "DELETE /api/tags/:id" do
    it "removes the tag" do
      tag = create(:tag)
      expect { delete "/api/tags/#{tag.id}" }.to change(Tag, :count).by(-1)
    end
  end
end
