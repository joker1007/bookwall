FactoryBot.define do
  factory :user_preference do
    user
    reader_spread { false }
    reader_direction { "ltr" }
    reader_scale { "fit" }
  end
end
