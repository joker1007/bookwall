# frozen_string_literal: true

# Playwright e2e 専用の environment。`test` のクローンだが、独自の SQLite DB
# (storage/test_e2e.sqlite3) と Active Storage root (tmp/storage_e2e) を参照し、
# rspec (常に RAILS_ENV=test) が使う test の DB / ファイルをブラウザ経由テストが
# 汚さないようにする。設定ドリフトを避けるため test の設定を丸ごと継承する。
require_relative "test"

Rails.application.configure do
  config.active_storage.service = :test_e2e
end
