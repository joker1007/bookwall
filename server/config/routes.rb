# frozen_string_literal: true

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
    resource :preferences, only: %i[show update]
    resources :libraries do
      resources :scans, only: %i[create index]
    end
    resources :books do
      member do
        post :favorite
        delete :favorite, action: :unfavorite
        get :file
      end
      get "pages/:n", to: "pages#show", as: :page, constraints: {n: /\d+/}
      resource :progress, only: %i[show update], controller: "reading_progresses"
    end
    resources :series
    resources :authors
    resources :tags
    resources :recent_reads, only: %i[index]
    resources :recent_favorites, only: %i[index]
    get "filesystem/browse", to: "filesystem#browse"
  end

  namespace :opds do
    root to: "feeds#root", as: :root
    get "/recent", to: "feeds#recent", as: :recent
    get "/favorites", to: "feeds#favorites", as: :favorites
    get "/libraries", to: "feeds#libraries", as: :libraries
    get "/libraries/:library_id", to: "feeds#library", as: :library
    # Include the format extension in the URL so OPDS readers that infer MIME
    # from the path (rather than the link's @type attribute) recognize the
    # downloaded book as EPUB/CBZ/PDF.
    get "/books/:book_id/file.:format",
      to: "downloads#file",
      as: :book_file,
      constraints: {format: /epub|cbz|pdf/}
    get "/books/:book_id/pages/:n", to: "pages#show", as: :book_page
  end
end
