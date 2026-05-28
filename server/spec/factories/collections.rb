# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    user
    sequence(:name) { |n| "Collection #{n}" }
  end
end
