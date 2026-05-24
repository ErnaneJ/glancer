# frozen_string_literal: true

module Glancer
  # Runs message processing in a background thread without relying on the host
  # app's Active Job queue adapter. Checks out a dedicated database connection
  # for the thread and releases it when done, regardless of success or failure.
  module AsyncRunner
    def self.call(message_id, question)
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          run(message_id, question)
        end
      rescue StandardError => e
        Glancer::Utils::Logger.error("AsyncRunner", "Thread raised outside job: #{e.message}")
      end
    end

    def self.run(message_id, question)
      message = Glancer::Message.find(message_id)
      chat    = message.chat

      message.update!(status: :processing)

      result     = Glancer::Workflow.run(chat.id, question)
      cfg        = Glancer.configuration
      used_model = "#{cfg.resolved_chat_provider}/#{cfg.resolved_chat_model}"

      message.update!(
        content: result[:content].to_s,
        code: result[:code],
        code_type: result[:code_type] || "sql",
        successful: result[:successful],
        llm_model: used_model,
        enriched_question: result[:enriched_question],
        status: :complete
      )

      message.code_versions.create!(code: message.code, source: :generated) if message.code.present?

      chat.update!(title: Glancer::Workflow::LLM.generate_title(question)) if chat.messages.where(role: :user).count == 1
    rescue StandardError => e
      Glancer::Utils::Logger.error("AsyncRunner", "Failed for message #{message_id}: #{e.message}")
      begin
        message&.update!(content: e.message, successful: false, status: :failed)
      rescue StandardError => update_error
        Glancer::Utils::Logger.error("AsyncRunner", "Could not mark message as failed: #{update_error.message}")
      end
    end
  end
end
