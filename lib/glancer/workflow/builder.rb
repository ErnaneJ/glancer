module Glancer
  module Workflow
    class Builder
      def self.build_sql(question, context_docs)
        Glancer::Utils::Logger.info("Workflow::Builder", "Generating SQL from question: #{question.inspect}")

        prompt = Glancer::Workflow::PromptBuilder.call(question, context_docs)
        Glancer::Utils::Logger.debug("Workflow::Builder", "Generated prompt for SQL generation:\n#{prompt}")

        chat = RubyLLM.chat(
          provider: Glancer.configuration.llm_provider,
          model: Glancer.configuration.llm_model
        )

        response = chat.ask(prompt)

        Glancer::Utils::Logger.info("Workflow::Builder",
                                    "LLM responded with SQL (length: #{response.content&.length || 0} characters)")

        response.content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to generate SQL: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Builder", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("SQL generation failed: #{e.message}"), cause: e
      end
    end
  end
end
