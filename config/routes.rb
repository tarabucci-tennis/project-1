Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get    "login",   to: "sessions#new",     as: :login
  post   "session", to: "sessions#create",  as: :session
  delete "session", to: "sessions#destroy"

  # Admin: user management
  resources :users, only: [ :index, :new, :create, :edit, :update, :destroy ]

  # Core app
  resources :teams, only: [ :index, :show ] do
    resources :matches, only: [ :index, :new, :create ] do
      member do
        get  "results", to: "matches#edit_results", as: :edit_results
        patch "results", to: "matches#update_results", as: :results
      end
      resource :lineup, only: [ :edit, :update ] do
        get "confirm", on: :member
        patch "confirm", on: :member
      end
    end
    get "captain", to: "matches#captain", as: :captain
  end

  # Availability AJAX endpoint (Phase 2 feature — routes preserved but unused on index page)
  post "matches/:match_id/availability", to: "availabilities#update", as: :match_availability

  get "profile",      to: "profiles#show", as: :profile
  get "players/:id",  to: "profiles#player", as: :player

  # Root: sends logged-in users to My Teams; logged-out users to login
  root "pages#home"
end
