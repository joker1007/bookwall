# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::ActiveStorageCacheHeaders do
  IMMUTABLE = "private, max-age=31536000, immutable"

  def env_for(path, method: "GET")
    {"PATH_INFO" => path, "REQUEST_METHOD" => method}
  end

  def app_returning(status, headers: {})
    ->(_env) { [status, headers, ["body"]] }
  end

  it "stamps Cache-Control on a 200 disk serve" do
    middleware = described_class.new(app_returning(200))
    _, headers, _ = middleware.call(env_for("/rails/active_storage/disk/abc/cover.jpg"))
    expect(headers["cache-control"]).to eq(IMMUTABLE)
  end

  it "stamps Cache-Control on a representation redirect (302)" do
    middleware = described_class.new(app_returning(302))
    _, headers, _ = middleware.call(env_for("/rails/active_storage/representations/redirect/xyz/_/cover.jpg"))
    expect(headers["cache-control"]).to eq(IMMUTABLE)
  end

  it "stamps Cache-Control on a range request (206)" do
    middleware = described_class.new(app_returning(206))
    _, headers, _ = middleware.call(env_for("/rails/active_storage/disk/abc/cover.jpg"))
    expect(headers["cache-control"]).to eq(IMMUTABLE)
  end

  it "leaves error responses uncached" do
    middleware = described_class.new(app_returning(404))
    _, headers, _ = middleware.call(env_for("/rails/active_storage/disk/abc/missing.jpg"))
    expect(headers["cache-control"]).to be_nil
  end

  it "ignores paths outside /rails/active_storage/" do
    middleware = described_class.new(app_returning(200))
    _, headers, _ = middleware.call(env_for("/api/books"))
    expect(headers["cache-control"]).to be_nil
  end

  it "ignores non-GET/HEAD methods so PUTs to disk aren't tagged" do
    middleware = described_class.new(app_returning(204))
    _, headers, _ = middleware.call(env_for("/rails/active_storage/disk/abc", method: "PUT"))
    expect(headers["cache-control"]).to be_nil
  end
end
