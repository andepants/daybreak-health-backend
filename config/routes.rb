Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"

  # GraphiQL IDE for development
  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end

  # Mount ActionCable for GraphQL subscriptions
  mount ActionCable.server => '/cable'

  # Webhooks
  namespace :webhooks do
    post '/intercom', to: 'intercom#create'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Custom health check endpoint
  get "/health", to: "health#check"

  # Defines the root path route ("/")
  # root "posts#index"

  # Hacked screen (for fun)
  get "/hacked", to: "hacked#show"
end
