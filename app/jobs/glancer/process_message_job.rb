# frozen_string_literal: true

module Glancer
  class ProcessMessageJob < Glancer::ApplicationJob
    queue_as :default

    def perform(message_id, question)
      message = Glancer::Message.find(message_id)
      chat    = message.chat

      message.update!(status: :processing)

      result = Glancer::Workflow.run(chat.id, question)

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

      # Generate chat title on the first user message
      chat.update!(title: Glancer::Workflow::LLM.generate_title(question)) if chat.messages.where(role: :user).count == 1
    rescue StandardError => e
      Glancer::Utils::Logger.error("ProcessMessageJob", "Failed for message #{message_id}: #{e.message}")
      message&.update!(content: e.message, successful: false, status: :failed)
      raise
    end
  end
end
