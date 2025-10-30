Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      get 'health', to: 'health#index'
      resources :score, only: :create
      post 'payments/checkout', to: 'payments#checkout'
      post 'payments/confirm', to: 'payments#confirm'
      post 'create-checkout-session', to: 'payments#checkout'
      post 'webhooks/stripe', to: 'webhooks#stripe'
      get  'device/status', to: 'devices#status'
      get  'device/reset', to: 'devices#reset'
      get  'subscription/status', to: 'subscriptions#status'
      get  'auth/check-email', to: 'auth#check_if_email_exists'
      post 'subscription/cancel', to: 'subscriptions#cancel'
      post 'auth/login', to: 'auth#login'
      post 'auth/signup', to: 'auth#signup'
      post 'auth/verify_email', to: 'auth#verify_email'
      post 'auth/resend_verification', to: 'auth#resend_verification'
      get  'auth/session', to: 'auth#session'
      post 'auth/logout', to: 'auth#logout'
    end
  end
end
