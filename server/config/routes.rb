Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resource :session, only: %i[show create destroy]
    resources :registrations, only: %i[create]
    resources :api_tokens, only: %i[index create destroy]
    resources :libraries
  end

  namespace :opds do
  end
end
