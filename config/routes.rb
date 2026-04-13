Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get    "login",   to: "sessions#new",     as: :login
  post   "session", to: "sessions#create",  as: :session
  delete "session", to: "sessions#destroy"
  get    "signup",  to: "registrations#new", as: :signup
  post   "signup",  to: "registrations#create"
  get    "forgot-password", to: "password_resets#new", as: :forgot_password
  post   "forgot-password", to: "password_resets#create"
  get    "reset-password/:token", to: "password_resets#edit", as: :edit_password_reset
  patch  "reset-password/:token", to: "password_resets#update", as: :reset_password
  # Legacy-user password setup (they signed in with email only and now need a password)
  get    "set-password",   to: "passwords#new",    as: :set_password
  patch  "set-password",   to: "passwords#update"

  # Admin: user management
  resources :users, only: [ :index, :new, :create, :edit, :update, :destroy ]

  # Join link
  get "join/:code", to: "joins#show", as: :join_team

  # Find / create teams
  get  "find-team", to: "teams#search", as: :find_team
  get  "create-team", to: "teams#new", as: :new_team
  post "create-team", to: "teams#create", as: :create_team

  # Core app
  resources :teams, only: [ :index, :show ] do
    resources :matches, only: [ :index, :new, :create, :show ] do
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
    member do
      post "add_player", to: "teams#add_player"
    end
  end

  # Availability AJAX endpoint (Phase 2 feature — routes preserved but unused on index page)
  post "matches/:match_id/availability", to: "availabilities#update", as: :match_availability

  get "profile",      to: "profiles#show", as: :profile
  get "players/:id",  to: "profiles#player", as: :player

  # Stats test page (pulls from Google Sheets)
  get "stats-test", to: "pages#stats_test", as: :stats_test

  # Lineups dashboard — all upcoming matches across user's teams
  get "lineups", to: "lineups#dashboard", as: :lineups_dashboard

  # Root: sends logged-in users to My Teams; logged-out users to login
  root "pages#home"
end
