# frozen_string_literal: true

require "retriable"

module Scanners
  # Application-level retry on SQLite BUSY, layered on top of the driver's busy_timeout.
  module SqliteRetryable
    # Only StatementInvalid matching this (BUSY) is retried; constraint violations are not.
    SQLITE_BUSY_PATTERN = /database is locked|SQLITE_BUSY|SQLite3::BusyException/

    def with_busy_retry(&block)
      Retriable.retriable(
        on: {ActiveRecord::StatementInvalid => SQLITE_BUSY_PATTERN},
        tries: 5,
        base_interval: 0.1,
        multiplier: 2.0,
        rand_factor: 0.25,
        on_retry: ->(exception, try, _elapsed, next_interval) {
          # On the final failure Retriable passes next_interval == nil.
          delay_text = next_interval ? "after #{next_interval.round(2)}s" : "(no more retries)"
          Rails.logger.warn do
            "[Scanners] SQLite busy, retry #{try} #{delay_text}: #{exception.message}"
          end
        },
        &block
      )
    end
  end
end
