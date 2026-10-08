Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  resources :orders, only: :show do
    member do
      get :verification_return, path: "verification-return"
      get :invoice_return, path: "invoice-return"
    end
  end

  namespace :api do
    post :precalc, to: "precalcs#create"
    get :rate, to: "rates#show"
    resources :orders, only: %i[create show]
  end

  namespace :webhooks do
    post :dragon_transfer, to: "dragon_transfer#create"
  end
end
