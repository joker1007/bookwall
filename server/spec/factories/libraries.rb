# frozen_string_literal: true

FactoryBot.define do
  factory :library do
    sequence(:name) { |n| "Library #{n}" }
    sequence(:path) { |n| "/mnt/books/library-#{n}" }
    association :owner, factory: :user
  end
end
