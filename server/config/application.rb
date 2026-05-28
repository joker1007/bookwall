# frozen_string_literal: true

require_relative "boot"
require_relative "../lib/middleware/spa_cache_headers"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module Bookwall
  class Application < Rails::Application
    config.load_defaults 8.1

    config.api_only = true

    config.active_record.schema_format = :sql

    config.autoload_lib(ignore: %w[assets tasks])

    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: false,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false
      g.system_tests = nil
    end

    config.middleware.use ActionDispatch::Cookies

    # Override Cache-Control on text/html responses so the SPA shell
    # revalidates after every deploy while the hashed Vite bundles can
    # still ride the long-cache header set in
    # config/environments/production.rb.
    config.middleware.use Middleware::SpaCacheHeaders

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins ENV.fetch("BOOKWALL_ALLOWED_ORIGINS", "http://localhost:5173").split(",")
        resource "*",
                 headers: :any,
                 methods: %i[get post put patch delete options head],
                 expose: %w[Authorization],
                 credentials: true,
                 max_age: 600
      end
    end
  end
end
