module Glancer
  class ChatsController < Glancer::ApplicationController
    layout "glancer/application"

    # GET / — temp chat view (no DB record created yet)
    def index
      @chats = Glancer::Chat.order(created_at: :desc)
      @chat  = nil
    end

    # GET /chats/:id
    def show
      @chat = Glancer::Chat.find_by(id: params[:id])

      unless @chat
        redirect_to glancer.root_path, alert: "Chat not found"
        return
      end

      @chats    = Glancer::Chat.order(created_at: :desc)
      @messages = @chat.messages.order(:created_at)
    end

    # POST /start — creates chat + first message, returns JSON { chat_id: }
    def start
      content = params[:content].to_s.strip
      return render json: { error: "Message required" }, status: :unprocessable_entity if content.blank?

      @chat    = Glancer::Chat.create!(title: "New Chat")
      @message = @chat.messages.create!(role: :user, content: content)

      response = Glancer::Workflow.run(@chat.id, @message.content)

      @response_message = @chat.messages.create!(
        role:         :assistant,
        content:      format_response(response),
        sql:          response[:sql],
        user_message: @message,
        successful:   response[:successful]
      )

      if @response_message.sql.present?
        @response_message.sql_versions.create!(sql: @response_message.sql, source: :generated)
      end

      title = Glancer::Workflow::LLM.generate_title(@message.content)
      @chat.update!(title: title)

      render json: { chat_id: @chat.id }
    rescue StandardError => e
      Glancer::Utils::Logger.error("ChatsController#start", e.message)
      render json: { error: e.message }, status: :internal_server_error
    end

    # DELETE /chats/:id
    def destroy
      @chat = Glancer::Chat.find(params[:id])
      @chat.destroy!
      redirect_to glancer.root_path
    end

    private

    def format_response(result)
      result[:content]
    end
  end
end
