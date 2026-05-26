class ScanLog < ApplicationRecord
  STATUSES = {pending: 0, running: 1, succeeded: 2, failed: 3}.freeze

  enum :status, STATUSES

  belongs_to :library
end
