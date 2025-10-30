Rails.application.routes.draw do
  scope path: '/golden_deployment' do
    root "examples#index"

    resources :examples, only: [:index, :show]

    # API endpoints with Bearer token authentication
    namespace :api do
      resources :examples, only: [:index] do
        post :bulk_upsert, on: :collection
      end
    end

    get "up" => "rails/health#show", as: :rails_health_check
  end
end
