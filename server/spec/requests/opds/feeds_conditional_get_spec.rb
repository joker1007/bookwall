# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds conditional GET via ETag", type: :request do
  include_context "opds feed request"

  it "sends a weak ETag on a navigation feed" do
    get "/opds", headers: {"Authorization" => auth_header}

    expect(response).to have_http_status(:ok)
    expect(response.headers["ETag"]).to be_present
    expect(response.headers["ETag"]).to start_with('W/"')
  end

  it "returns 304 with no body when If-None-Match matches" do
    get "/opds", headers: {"Authorization" => auth_header}
    etag = response.headers["ETag"]

    get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag}

    expect(response).to have_http_status(:not_modified)
    expect(response.body).to be_empty
    expect(response.headers["Content-Encoding"]).to be_nil
  end

  it "skips compression entirely on a 304 even when an encoding is acceptable" do
    get "/opds", headers: {"Authorization" => auth_header}
    etag = response.headers["ETag"]

    expect(Opds::Compression).not_to receive(:encode)
    get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag, "Accept-Encoding" => "gzip"}

    expect(response).to have_http_status(:not_modified)
  end

  it "re-renders a 200 when the feed content has changed" do
    get "/opds/recent", headers: {"Authorization" => auth_header}
    etag = response.headers["ETag"]

    create(:book, library: library, title: "FreshlyAdded")
    get "/opds/recent", headers: {"Authorization" => auth_header, "If-None-Match" => etag}

    expect(response).to have_http_status(:ok)
    expect(response.headers["ETag"]).not_to eq(etag)
    expect(response.body).to include("FreshlyAdded")
  end

  it "matches the stored ETag regardless of the negotiated Content-Encoding" do
    get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "gzip"}
    etag = response.headers["ETag"]
    expect(response.headers["Content-Encoding"]).to eq("gzip")

    get "/opds", headers: {"Authorization" => auth_header, "If-None-Match" => etag, "Accept-Encoding" => "identity"}

    expect(response).to have_http_status(:not_modified)
  end
end
