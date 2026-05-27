# frozen_string_literal: true

FactoryBot.define do
  factory :series do
    library
    sequence(:name) { |n| "Series #{n}" }
  end
end
