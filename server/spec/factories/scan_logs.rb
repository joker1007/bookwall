# frozen_string_literal: true

FactoryBot.define do
  factory :scan_log do
    library
    started_at { Time.current }
    status { :pending }
  end
end
