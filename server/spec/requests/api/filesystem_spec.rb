# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Filesystem", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password) }

  def sign_in!
    post "/api/session", params: {email_address: user.email_address, password: password}
    expect(response).to have_http_status(:created)
  end

  describe "GET /api/filesystem/browse" do
    it "requires authentication" do
      get "/api/filesystem/browse"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists subdirectories of the requested path and reports the parent" do
      sign_in!

      Dir.mktmpdir do |root|
        Dir.mkdir(File.join(root, "books"))
        Dir.mkdir(File.join(root, "code"))
        File.write(File.join(root, "ignored.txt"), "x")

        get "/api/filesystem/browse", params: {path: root}

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["path"]).to eq(File.expand_path(root))
        expect(body["parent"]).to eq(File.expand_path(File.dirname(root)))
        expect(body["exists"]).to be(true)
        expect(body["readable"]).to be(true)

        names = body["entries"].map { |e| e["name"] }
        # Only directories are reported, sorted case-insensitively.
        expect(names).to eq(%w[books code])
      end
    end

    it "returns null parent at the filesystem root" do
      sign_in!

      get "/api/filesystem/browse", params: {path: "/"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["parent"]).to be_nil
    end

    it "treats a file argument as a request for its containing directory" do
      sign_in!

      Dir.mktmpdir do |root|
        nested = File.join(root, "nested")
        Dir.mkdir(nested)
        file = File.join(root, "book.cbz")
        File.write(file, "fake")

        get "/api/filesystem/browse", params: {path: file}

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["path"]).to eq(File.expand_path(root))
        expect(body["entries"].map { |e| e["name"] }).to eq(%w[nested])
      end
    end

    it "reports exists=false for a path that doesn't resolve" do
      sign_in!

      get "/api/filesystem/browse", params: {path: "/does/not/exist/anywhere/at/all"}

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["exists"]).to be(false)
      expect(body["entries"]).to be_empty
    end
  end
end
