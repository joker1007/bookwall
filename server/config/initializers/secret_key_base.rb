# frozen_string_literal: true

# Bookwall doesn't use Rails' encrypted credentials — there are no
# secrets the app needs to read at boot beyond `secret_key_base`. To
# keep deployment friction low (no `RAILS_MASTER_KEY` to ship, no
# `config/master.key` to leak), wire `secret_key_base` directly:
#
# - development / test → a fixed string committed to the repo. It's
#   intentionally not a real secret; sessions / cookies that ride on it
#   are scoped to a developer's local machine.
# - production → must come from `ENV["SECRET_KEY_BASE"]`. The Docker
#   entrypoint script generates one at first boot and persists it under
#   `$BOOKWALL_DATA_DIR/secret_key_base`, then re-exports it on every
#   subsequent start — so the volume holding the SQLite data also
#   holds the signing key.
case Rails.env
when "development"
  Rails.application.config.secret_key_base =
    "DEVELOPMENT_ONLY_DO_NOT_USE_IN_PRODUCTION_" \
    "8f3a1c5d9b7e2f4a6c8d0e1b3a5f7c9d2e4b6a8f0c1d3e5b7a9f1c3d5e7b9f1a"
when "test"
  Rails.application.config.secret_key_base =
    "TEST_ONLY_DO_NOT_USE_IN_PRODUCTION_" \
    "1a3b5c7d9e1f2a4b6c8d0e2f4a6b8c0d2e4f6a8b0c2d4e6f8a0b2c4d6e8f0a2b"
end
