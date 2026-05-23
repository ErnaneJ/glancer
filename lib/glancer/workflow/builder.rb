# frozen_string_literal: true

module Glancer
  module Workflow
    class Builder
      def self.build_sql(question, embeddings, history: [])
        Glancer::Utils::Logger.info("Workflow::Builder", "Generating SQL from question: #{question.inspect}")

        prompt = Glancer::Workflow::PromptBuilder.call(
          question, embeddings, history: history, few_shot_examples: recent_examples
        )
        Glancer::Utils::Logger.debug("Workflow::Builder", "Generated prompt for SQL generation:\n#{prompt}")

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_sql_provider,
          model: Glancer.configuration.resolved_sql_model,
          assume_model_exists: true
        )

        response = chat.ask(prompt)

        Glancer::Utils::Logger.info("Workflow::Builder",
                                    "LLM responded with SQL (length: #{response.content&.length || 0} characters)")

        response.content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to generate SQL: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Builder", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error, "SQL generation failed: #{e.message}"
      end

      def self.recent_examples
        Glancer::Audit
          .where(adapter: Glancer.configuration.resolved_adapter.to_s)
          .where.not(question: [nil, ""])
          .order(executed_at: :desc)
          .limit(3)
          .pluck(:question, :sql)
      rescue StandardError
        []
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

          Your task is to correct the SQL query so it becomes valid for the #{Glancer.configuration.resolved_adapter.to_s.upcase} adapter.
          - Return ONLY the corrected SQL.
          - Do not provide explanations or comments.
          - Ensure it remains a safe SELECT statement.
        PROMPT

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_sql_provider,
          model: Glancer.configuration.resolved_sql_model,
          assume_model_exists: true
        )

        response = chat.ask(prompt)

        # Clean the response to ensure we only have the raw SQL
        Glancer::Workflow::SQLExtractor.extract(response.content)
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to fix SQL: #{e.message}")
        raise Glancer::Error, "SQL correction workflow failed: #{e.message}"
      end

      def self.build_ar_code(question, embeddings, history: [])
        Glancer::Utils::Logger.info("Workflow::Builder", "Generating AR code from question: #{question.inspect}")

        prompt = Glancer::Workflow::ARPromptBuilder.call(question, embeddings, history: history)

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_sql_provider,
          model: Glancer.configuration.resolved_sql_model,
          assume_model_exists: true
        )

        response = chat.ask(prompt)
        Glancer::Utils::Logger.info("Workflow::Builder",
                                    "LLM responded with AR code (length: #{response.content&.length || 0} chars)")
        response.content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to generate AR code: #{e.class} - #{e.message}")
        raise Glancer::Error, "AR code generation failed: #{e.message}"
      end

      def self.fix_ar_code(failed_code, error_message)
        Glancer::Utils::Logger.info("Workflow::Builder", "Attempting to fix failed AR expression...")

        prompt = <<~PROMPT
          The following Ruby/ActiveRecord expression failed to execute:
          ```ruby
          #{failed_code}
          ```

          The error returned was:
          "#{error_message}"

          Your task is to correct the Ruby expression so it becomes valid and read-only.
          - Return ONLY the corrected Ruby expression (optionally in a ```ruby block).
          - Do not provide explanations or comments.
          - Ensure it uses only read methods (where, joins, select, count, sum, pluck, etc.).
          - NEVER use .destroy, .delete, .update, .save, .create, or any write method.
        PROMPT

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_sql_provider,
          model: Glancer.configuration.resolved_sql_model,
          assume_model_exists: true
        )

        response = chat.ask(prompt)
        Glancer::Workflow::ARExtractor.extract(response.content)
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Builder", "Failed to fix AR code: #{e.message}")
        raise Glancer::Error, "AR code correction failed: #{e.message}"
      end
    end
  end
end
