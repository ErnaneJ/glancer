module Glancer
  module Workflow
    class Builder
      def self.build_sql(question, embeddings, history: [])
        Glancer::Utils::Logger.info("Workflow::Builder", "Generating SQL from question: #{question.inspect}")

        prompt = Glancer::Workflow::PromptBuilder.call(question, embeddings, history: history)
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

      def self.fix_sql(failed_sql, error_message)
        Glancer::Utils::Logger.info("Workflow::Builder", "Attempting to fix failed SQL...")

        prompt = <<~PROMPT
          The following SQL query failed to execute:
          ```sql
          #{failed_sql}
          ```

          The database returned the following error message:
          "#{error_message}"

          Your task is to correct the SQL query so it becomes valid for the #{Glancer.configuration.adapter.upcase} adapter.
          - Return ONLY the corrected SQL.
          - Do not provide explanations or comments.
          - Ensure it remains a safe SELECT statement.
        PROMPT

        chat = RubyLLM.chat(
          provider: Glancer.configuration.llm_provider,
          model: Glancer.configuration.llm_model
        )

        response = chat.ask(prompt)

        # Clean the response to ensure we only have the raw SQL
        Glancer::Workflow::SQLExtractor.extract(response.content)
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to fix SQL: #{e.message}")
        raise Glancer::Error.new("SQL correction workflow failed: #{e.message}")
      end
    end
  end
end
