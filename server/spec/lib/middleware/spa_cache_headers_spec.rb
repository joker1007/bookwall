# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::SpaCacheHeaders do
  def build_response(content_type:, cache_control: nil)
    headers = {}
    headers["content-type"] = content_type if content_type
    headers["cache-control"] = cache_control if cache_control
    [200, headers, ["body"]]
  end

  def app_returning(response)
    ->(_env) { response }
  end

  it "downgrades the cache-control on text/html responses to no-cache" do
    inner = app_returning(build_response(
      content_type: "text/html; charset=utf-8",
      cache_control: "public, max-age=31536000, immutable",
    ))
    middleware = described_class.new(inner)

    _status, headers, _body = middleware.call({})
    expect(headers["cache-control"]).to eq("no-cache")
  end

  it "sets cache-control on text/html responses that arrived without one" do
    inner = app_returning(build_response(content_type: "text/html"))
    middleware = described_class.new(inner)

    _status, headers, _body = middleware.call({})
    expect(headers["cache-control"]).to eq("no-cache")
  end

  it "leaves non-html responses alone" do
    inner = app_returning(build_response(
      content_type: "application/javascript",
      cache_control: "public, max-age=31536000, immutable",
    ))
    middleware = described_class.new(inner)

    _status, headers, _body = middleware.call({})
    expect(headers["cache-control"]).to eq("public, max-age=31536000, immutable")
  end

  it "recognises title-cased Content-Type for downstream middleware that emits it" do
    inner = app_returning([200, {"Content-Type" => "text/html"}, ["body"]])
    middleware = described_class.new(inner)

    _status, headers, _body = middleware.call({})
    expect(headers["cache-control"]).to eq("no-cache")
  end
end
