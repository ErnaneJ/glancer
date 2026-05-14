Glancer::Engine.routes.draw do
  root to: "chats#index"

  resources :chats, only: %i[index show destroy] do
    resources :messages, only: [:create]
  end

  post "/start", to: "chats#start", as: :start_session

  get  "/messages/:id/info",           to: "messages#message_info",  as: :message_info
  post "/messages/:id/run_sql",         to: "messages#run_sql",       as: :run_message_sql
  post "/messages/:id/open_in_blazer",  to: "messages#open_in_blazer", as: :open_message_in_blazer

  get   "/db-schema", to: "schema#show",    as: :db_schema
  get   "/settings",  to: "settings#show",  as: :settings
  patch "/settings",  to: "settings#update"
end
