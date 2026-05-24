# frozen_string_literal: true

module Glancer
  class MessagesController < Glancer::ApplicationController
    def create
      @chat    = Glancer::Chat.find(params[:chat_id])
      @message = @chat.messages.create!(message_params.merge(role: :user))

      # Placeholder written immediately; ProcessMessageJob fills it in async.
      @response_message = @chat.messages.create!(
        role: :assistant,
        content: "",
        code_type: "sql",
        user_message: @message,
        status: :processing
      )

      Glancer::AsyncRunner.call(@response_message.id, @message.content)

      @chats = Glancer::Chat.order(created_at: :desc)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to glancer.chat_path(@chat) }
      end
    end

    # Clients poll this endpoint every ~2 s while waiting for the async runner.
    # Returns 204 while still processing; Turbo Stream when complete or failed.
    # A hard timeout marks stale messages as failed so the UI doesn't loop forever.
    PROCESSING_TIMEOUT_SECONDS = 300

    def poll
      @message = Glancer::Message.find(params[:id])

      if (@message.processing? || @message.pending?) &&
         @message.updated_at < PROCESSING_TIMEOUT_SECONDS.seconds.ago
        @message.update!(content: "Request timed out. Please try again.", successful: false, status: :failed)
      end

      return head(:no_content) if @message.processing? || @message.pending?

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "message-#{@message.id}",
            partial: "glancer/messages/message",
            locals: { message: @message }
          )
        end
      end
    end

    def run_code
      @message = Glancer::Message.find(params[:id])
      custom_code = params[:custom_code].presence

      if custom_code
        if @message.code_type == "activerecord"
          Glancer::Workflow::ARSanitizer.ensure_safe!(custom_code)
          @message.update!(code: custom_code, user_edited_code: true)
          @message.code_versions.create!(code: custom_code, source: :user_edited)
          @data = Glancer::Workflow::ARExecutor.execute(@message.code, message_id: @message.id)
        else
          Glancer::Workflow::SQLSanitizer.ensure_safe!(custom_code)
          @message.update!(code: custom_code, user_edited_code: true)
          @message.code_versions.create!(code: custom_code, source: :user_edited)
          @data = Glancer::Workflow::Executor.execute(@message.code, message_id: @message.id)
        end
      elsif @message.code_type == "activerecord"
        @data = Glancer::Workflow::ARExecutor.execute(@message.code, message_id: @message.id)
      else
        @data = Glancer::Workflow::Executor.execute(@message.code, message_id: @message.id)
      end

      respond_to do |format|
        format.turbo_stream do
          if @data.is_a?(Hash) && @data[:error]
            render turbo_stream: turbo_stream.update("results-#{@message.id}",
                                                     partial: "glancer/messages/execution_error",
                                                     locals: { error_message: @data[:message] })
          else
            chart_data = Glancer::ChartAnalyzer.analyze(@data)
            render turbo_stream: turbo_stream.update("results-#{@message.id}",
                                                     partial: "glancer/messages/data_table",
                                                     locals: { data: @data, chart_data: chart_data })
          end
        end
      end
    end

    def open_in_blazer
      @message = Glancer::Message.find(params[:id])
      blazer_path = Glancer.configuration.resolved_blazer_path

      unless blazer_path.present? && defined?(Blazer::Query)
        redirect_to glancer.root_path, alert: "Blazer não está disponível."
        return
      end

      unless @message.code_type == "sql" || @message.code_type.nil?
        redirect_to glancer.root_path, alert: "Only SQL queries can be opened in Blazer."
        return
      end

      query = Blazer::Query.create!(
        name: "Glancer: #{@message.user_message&.content&.truncate(60) || "Query"}",
        statement: @message.code.strip
      )

      redirect_to "#{blazer_path}/queries/#{query.id}/edit", allow_other_host: true
    rescue StandardError => e
      Glancer::Utils::Logger.error("MessagesController", "Failed to create Blazer query: #{e.message}")
      redirect_to glancer.root_path, alert: "Não foi possível criar a query no Blazer: #{e.message}"
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
                                                 locals: { message_info: @message_for_info })
          ]
        end
      end
    end

    private

    def message_params
      params.require(:message).permit(:content)
    end

    def format_response(result)
      result[:content]
    end
  end
end
