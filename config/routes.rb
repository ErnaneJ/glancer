Glancer::Engine.routes.draw do
  resources :chats, only: [:index, :show] do
    resources :messages, only: [:create]
  end
end
