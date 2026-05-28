# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opds::Feeds Content-Encoding negotiation", type: :request do
  include_context "opds feed request"

  it "leaves the feed uncompressed when no Accept-Encoding is sent" do
    get "/opds", headers: {"Authorization" => auth_header}

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Encoding"]).to be_nil
    expect(response.headers["Vary"]).to include("Accept-Encoding")
    expect(response.body).to include("<title>Bookwall</title>")
  end

  {
    "gzip" => ->(body) { Zlib.gunzip(body) },
    "deflate" => ->(body) { Zlib::Inflate.inflate(body) },
    "br" => ->(body) { Brotli.inflate(body) },
    "zstd" => ->(body) { Zstd.decompress(body) }
  }.each do |encoding, decode|
    it "encodes the navigation feed with #{encoding} when requested" do
      get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => encoding}

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Encoding"]).to eq(encoding)
      expect(response.headers["Vary"]).to include("Accept-Encoding")
      expect(decode.call(response.body)).to include("<title>Bookwall</title>")
    end

    it "encodes an acquisition feed with #{encoding} when requested" do
      create(:book, library: library, title: "Compressible", page_count: 10)
      get "/opds/recent", headers: {"Authorization" => auth_header, "Accept-Encoding" => encoding}

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Encoding"]).to eq(encoding)
      expect(decode.call(response.body)).to include("Compressible")
    end
  end

  it "prefers zstd when the client offers several codecs equally" do
    get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "deflate, gzip, br, zstd"}

    expect(response.headers["Content-Encoding"]).to eq("zstd")
    expect(Zstd.decompress(response.body)).to include("<title>Bookwall</title>")
  end

  it "does not compress when only unsupported encodings are offered" do
    get "/opds", headers: {"Authorization" => auth_header, "Accept-Encoding" => "compress"}

    expect(response.headers["Content-Encoding"]).to be_nil
    expect(response.body).to include("<title>Bookwall</title>")
  end
end
