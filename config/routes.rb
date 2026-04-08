Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get  "login",  to: "sessions#new",     as: :login
  post "session", to: "sessions#create",  as: :session
  delete "session", to: "sessions#destroy"

  # Registration
  get  "signup", to: "registrations#new", as: :signup
  post "signup", to: "registrations#create"
  get  "join/:code", to: "registrations#join", as: :join_team

  # Admin: user management
  resources :users, only: [ :index, :new, :create, :edit, :update, :destroy ]

  get "tennis",  to: "pages#tennis",    as: :tennis
  get "profile", to: "profiles#show",  as: :profile

  # Teams with full CRUD
  resources :teams, only: [ :index, :show, :new, :create, :edit, :update ] do
    member do
      get :availability_grid
    end
    # Player stats per team
    resources :player_stats, only: [ :show ]

    # Export
    get "export", to: "exports#team_data", as: :export

    resources :scheduled_matches, only: [ :show, :new, :create, :edit, :update ] do
      member do
        patch :update_lineup
        patch :update_availability
      end
      resources :match_scores, only: [ :new, :create, :edit, :update ]
    end
  end

  # Settings & Notifications
  get  "settings", to: "settings#show", as: :settings
  patch "settings/notification_preference", to: "settings#update_notification_preference", as: :notification_preference
  patch "settings/mark_notifications_read", to: "settings#mark_notifications_read", as: :mark_notifications_read

  root "pages#home"
end
