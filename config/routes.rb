# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  resource :tax_exemptions, controller: "taxjar_customers" do
    get :nexus_regions
  end
  namespace :admin do
    resource :taxjar_settings, only: [:edit, :update]
    resources :transaction_sync_batches, only: [:index, :show, :create]
    resources :users, only: [] do
      resource :tax_exemptions, controller: "taxjar_customers" do
        resources :exempt_regions, controller: "taxjar_exempt_regions" do
          get :approve, :disapprove, on: :member
        end
      end
    end
    get 'taxjar_settings/sync_nexus_regions', to: 'taxjar_settings#sync_nexus_regions'
    get 'taxjar_settings/sync_tax_categories', to: 'taxjar_settings#sync_tax_categories'
    post 'taxjar_settings/backfill_transactions', to: 'taxjar_settings#backfill_transactions'

    resources :orders do
      member do
        get :taxjar_transactions
      end
    end
  end
end
