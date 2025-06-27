module Glancer
  class ChatsController < ApplicationController
    def index
      @chats = Chat.order(created_at: :desc)
    end

    def show
      @chat = Chat.find(params[:id])
      @messages = @chat.messages.order(:created_at)
    end
  end
end
