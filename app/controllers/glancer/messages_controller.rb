# frozen_string_literal: true

module Glancer
  class MessagesController < Glancer::ApplicationController
    def create
      @chat = Glancer::Chat.find(params[:chat_id])
      @message = @chat.messages.create!(message_params.merge(role: :user))

      response = Glancer::Workflow.run(@chat.id, @message.content)

      cfg = Glancer.configuration
      used_model = "#{cfg.resolved_chat_provider}/#{cfg.resolved_chat_model}"

      @response_message = @chat.messages.create!(
        role: :assistant,
        content: format_response(response),
        sql: response[:sql],
        user_message: @message,
        successful: response[:successful],
        llm_model: used_model
      )

      @response_message.sql_versions.create!(sql: @response_message.sql, source: :generated) if @response_message.sql.present?

      # Generate title from first user message
      if @chat.messages.where(role: :user).count == 1
        title = Glancer::Workflow::LLM.generate_title(@message.content)
        @chat.update!(title: title)
      end

      @chats = Glancer::Chat.order(created_at: :desc)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to glancer.chat_path(@chat) }
      end
    end

    def run_sql
      @message = Glancer::Message.find(params[:id])
      custom_sql = params[:custom_sql].presence

      if custom_sql
        Glancer::Workflow::SQLSanitizer.ensure_safe!(custom_sql)
        @message.update!(sql: custom_sql, user_edited_sql: true)
        @message.sql_versions.create!(sql: custom_sql, source: :user_edited)
      end

      @data = Glancer::Workflow::Executor.execute(@message.sql, message_id: @message.id)

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

      query = Blazer::Query.create!(
        name: "Glancer: #{@message.user_message&.content&.truncate(60) || 'Query'}",
        statement: @message.sql.strip
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
