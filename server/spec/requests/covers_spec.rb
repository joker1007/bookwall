# frozen_string_literal: true

require "rails_helper"

# Deliberately unauthenticated: like Active Storage's proxy endpoints,
# possession of a valid signed id is the access token.
RSpec.describe "Covers" do
  let(:library) { create(:library) }
  let(:book) { create(:book, library: library) }

  def attach_real_cover(book)
    Rails.root.join("spec/fixtures/files/sample_image_dir/001.jpg").open do |io|
      book.cover.attach(io: io, filename: "cover.jpg", content_type: "image/jpeg")
    end
    book
  end

  describe "GET /covers/blobs/:signed_id/*filename" do
    it "serves the blob bytes with public immutable caching" do
      attach_cover(book)

      get CoverUrlHelper.cover_url(book)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("fake-jpg-bytes")
      expect(response.headers["Content-Type"]).to eq("image/jpeg")
      expect(response.headers["Content-Disposition"]).to include("inline")
      expect(response.headers["Cache-Control"]).to eq("max-age=31536000, public, immutable")
    end

    it "returns 404 for a tampered signed id" do
      get "/covers/blobs/bogus/cover.jpg"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the blob has been purged" do
      attach_cover(book)
      url = CoverUrlHelper.cover_url(book)
      book.cover.purge

      get url

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when the file is missing from disk" do
      attach_cover(book)
      blob = book.cover.blob
      blob.service.delete(blob.key)

      get CoverUrlHelper.cover_url(book)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /covers/thumbs/:signed_blob_id/:variation_key/*filename" do
    it "serves a preprocessed thumb variant" do
      attach_real_cover(book)
      book.cover.variant(:thumb).processed

      get CoverUrlHelper.cover_thumb_url(book)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("image/jpeg")
      expect(response.headers["Cache-Control"]).to eq("max-age=31536000, public, immutable")
      expect(response.body).to be_present
    end

    it "processes the variant on demand when it has not been preprocessed" do
      attach_real_cover(book)

      expect {
        get CoverUrlHelper.cover_thumb_url(book)
      }.to change(ActiveStorage::VariantRecord, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a tampered variation key" do
      attach_real_cover(book)

      get "/covers/thumbs/#{book.cover.blob.signed_id}/bogus/cover.jpg"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unrepresentable blob" do
      attach_cover(book, filename: "cover.svg", content_type: "image/svg+xml")
      path = Rails.application.routes.url_helpers.cover_thumb_path(
        book.cover.blob.signed_id,
        ActiveStorage::Variation.encode(resize_to_limit: [240, nil]),
        "cover.svg"
      )

      get path

      expect(response).to have_http_status(:not_found)
    end
  end
end
