# frozen_string_literal: true

require "retriable"

module Scanners
  # Wraps a SQLite write block so it survives transient BUSY errors from other
  # writers (e.g. the web process committing favorites or reading progress
  # while the scanner is also writing). The driver already honors busy_timeout;
  # this adds an application-level retry on top so very long contention windows
  # still succeed instead of failing the whole scan.
  module SqliteRetryable
    # ActiveRecord::StatementInvalid whose message (or wrapped cause) matches
    # one of these patterns means SQLite returned BUSY — the writer can retry
    # safely. Other StatementInvalid causes (constraint violations etc.) are
    # not retried.
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
