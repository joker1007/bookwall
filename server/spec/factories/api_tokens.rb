FactoryBot.define do
  factory :api_token do
    user
    sequence(:name) { |n| "token-#{n}" }
    token_digest { Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32)) }
  end
end
