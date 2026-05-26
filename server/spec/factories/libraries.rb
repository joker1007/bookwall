FactoryBot.define do
  factory :library do
    sequence(:name) { |n| "Library #{n}" }
    sequence(:path) { |n| "/mnt/books/library-#{n}" }
  end
end
