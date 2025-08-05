Glancer::Engine.routes.draw do
  resources :chats, only: %i[index show create destroy] do
    resources :messages, only: [:create]
  end

  get "/messages/:id/info", to: "messages#message_info", as: :message_info

  root to: "chats#index"
end
