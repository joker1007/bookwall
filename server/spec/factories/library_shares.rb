# frozen_string_literal: true

FactoryBot.define do
  factory :library_share do
    library
    user
  end
end
