# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SPA fallback", type: :request do
  describe "GET /" do
    it "redirects to /ui/" do
      get "/"
      expect(response).to redirect_to("/ui/")
    end
  end

  describe "GET /ui and /ui/*" do
    it "returns the SPA index for /ui when the bundle exists" do
      Tempfile.create(["bookwall-spa", ".html"]) do |tmp|
        tmp.write("<!doctype html><html><body>spa</body></html>")
        tmp.close
        index_path = Rails.public_path.join("ui/index.html")
        FileUtils.mkdir_p(index_path.dirname)
        FileUtils.cp(tmp.path, index_path)
        begin
          get "/ui"
          expect(response).to have_http_status(:ok)
          expect(response.media_type).to start_with("text/html")
          get "/ui/books/123"
          expect(response).to have_http_status(:ok)
        ensure
          FileUtils.rm_f(index_path)
        end
      end
    end

    it "returns 404 when the SPA bundle is not built" do
      index_path = Rails.public_path.join("ui/index.html")
      FileUtils.rm_f(index_path)
      get "/ui"
      expect(response).to have_http_status(:not_found)
    end
  end
end
