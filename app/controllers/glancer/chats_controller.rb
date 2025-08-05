module Glancer
  class ChatsController < ApplicationController
    layout "glancer/application"

    def index
      @chats = Glancer::Chat.order(created_at: :desc)
      redirect_to glancer.chat_path(
        @chats.first ||
        Glancer::Chat.create!(title: "Chat #{Time.current.strftime("%H:%M")}")
      )
    end

    def show
      @chat = Glancer::Chat.find_by(id: params[:id])

      unless @chat
        flash[:alert] = "Chat not found"
        redirect_to glancer.chats_path and return
      end

      @chats = Glancer::Chat.order(created_at: :desc)
      @messages = @chat.messages.order(:created_at)

      respond_to do |format|
        format.html { render :index } # Sempre renderize o index que contém a estrutura completa
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("main-content", partial: "glancer/chats/show",
                                                                    locals: { chat: @chat, chats: @chats, messages: @messages })
        end
      end
    end

    def create
      @chat = Glancer::Chat.create!(title: "Chat #{Time.current.strftime("%H:%M")}")
      @chats = Glancer::Chat.order(created_at: :desc)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("sidebar-chat-list", partial: "glancer/chats/sidebar_chat_list",
                                                      locals: { chat: @chat, chats: @chats }),
            turbo_stream.replace("main-content", partial: "glancer/chats/show",
                                                 locals: { chat: @chat, chats: @chats, messages: @chat.messages.order(:created_at) })
          ]
        end
        format.html { redirect_to glancer.chat_path(@chat) }
      end
    end

    def destroy
      @chat = Glancer::Chat.find(params[:id])
      @chats = Glancer::Chat.order(created_at: :desc)

      @chat.destroy!

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("sidebar-chat-list", partial: "glancer/chats/sidebar_chat_list",
                                                      locals: { chat: @chat, chats: @chats }),
            turbo_stream.replace("main-content", partial: "glancer/chats/show",
                                                 locals: { chat: @chat, chats: @chats, messages: @chat.messages.order(:created_at) })
          ]
        end
        format.html { redirect_to glancer.chats_path }
      end
    end
  end
end
