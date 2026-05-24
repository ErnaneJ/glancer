# frozen_string_literal: true

module Glancer
  # :nodoc:
  class ChatsController < Glancer::ApplicationController
    layout "glancer/application"

    def index
      @chats = Glancer::Chat.order(created_at: :desc)
      @chat  = nil
    end

    def show
      @chat = Glancer::Chat.find_by(id: params[:id])
      return redirect_to(glancer.root_path, alert: "Chat not found") unless @chat

      @chats    = Glancer::Chat.order(created_at: :desc)
      @messages = @chat.messages.order(:created_at)
    end

    def start
      content = params[:content].to_s.strip
      return render(json: { error: "Message required" }, status: :unprocessable_entity) if content.blank?

      @chat    = Glancer::Chat.create!(title: "New Chat")
      @message = @chat.messages.create!(role: :user, content: content)

      @response_message = @chat.messages.create!(
        role: :assistant,
        content: "",
        code_type: "sql",
        user_message: @message,
        status: :processing
      )

      Glancer::AsyncRunner.call(@response_message.id, content)

      render json: { chat_id: @chat.id }
    rescue StandardError => e
      Glancer::Utils::Logger.error("ChatsController#start", e.message)
      render json: { error: e.message }, status: :internal_server_error
    end

    def destroy
      Glancer::Chat.find(params[:id]).destroy!
      redirect_to glancer.root_path
    end
  end
end
