Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :books, only: %i[index show create destroy], param: :serial_number do
        # PATCH /api/v1/books/:serial_number/status
        patch :status, on: :member, action: :update_status
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
