Glancer::Engine.routes.draw do
  resources :chats, only: %i[index show create destroy] do
    resources :messages, only: [:create]
  end

  get "/messages/:id/info", to: "messages#message_info", as: :message_info
  post "/messages/:id/run_sql", to: "messages#run_sql", as: :run_message_sql

  root to: "chats#index"
end
