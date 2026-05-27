Rails.application.routes.draw do
  root to: redirect("/ui/")

  get "up" => "rails/health#show", as: :rails_health_check

  get "/ui", to: "spa#index"
  get "/ui/*unmatched", to: "spa#index"

  namespace :api do
    if ENV["BOOKWALL_E2E_RESET"] == "1"
      post "test_support/reset", to: "test_support#reset"
    end

    resource :session, only: %i[show create destroy]
    resources :registrations, only: %i[create]
    resources :api_tokens, only: %i[index create destroy]
    resources :libraries do
      resources :scans, only: %i[create]
    end
    resources :books do
      member do
        post :favorite
        delete :favorite, action: :unfavorite
      end
    end
    resources :series
    resources :authors
    resources :tags
  end

  namespace :opds do
    root to: "feeds#root", as: :root
    get "/recent", to: "feeds#recent", as: :recent
    get "/favorites", to: "feeds#favorites", as: :favorites
    get "/libraries", to: "feeds#libraries", as: :libraries
    get "/libraries/:library_id", to: "feeds#library", as: :library
    get "/books/:book_id/file", to: "downloads#file", as: :book_file
    get "/books/:book_id/pages/:n", to: "pages#show", as: :book_page
  end
end
