module Glancer
  class MessagesController < ApplicationController
    def create
      @chat = Glancer::Chat.find(params[:chat_id])
      @message = @chat.messages.create!(message_params.merge(role: :user))

      response = Glancer::Workflow.run(@message.content)

      @response_message = @chat.messages.create!(
        role: :assistant,
        content: format_response(response),
        sql: response[:sql],
        user_message: @message
      )

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to glancer.chat_path(@chat) }
      end
    end

    def message_info
      @message_for_info = begin
        Glancer::Message.find(params[:id])
      rescue StandardError
        nil
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("message-info", partial: "glancer/messages/message_info",
                                                 locals: { message_for_info: @message_for_info })
          ]
        end
      end
    end

    private

    def message_params
      params.require(:message).permit(:content)
    end

    def format_response(result)
      puts "--------------------------------------"
      puts result[:content]
      puts "--------------------------------------"
      result[:content]
    end
  end
end
