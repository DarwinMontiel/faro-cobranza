Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"

  resources :clients, param: :document_number, except: :destroy
  resources :obligations, param: :number, only: %i[index show] do
    resources :collection_activities, only: :create
    resources :payment_agreements, param: :reference, only: %i[new create] do
      post :plan, on: :collection
    end
  end
  resources :payment_agreements, param: :reference, only: %i[index show]
  resources :api_tokens, only: %i[index create destroy]

  namespace :api do
    namespace :v1 do
      resources :clients, param: :document_number, only: %i[index show]
      resources :obligations, param: :number, only: %i[index show]
      resources :collection_activities, only: :create
      resources :payment_agreements, param: :reference, only: %i[create show]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
