# frozen_string_literal: true
module Glancer
  module Workflow
    class PromptBuilder
      def self.custom_instructions_block
        custom = Glancer::Setting.get("custom_instructions")
        custom.present? ? "CUSTOM RULES — MUST BE FOLLOWED STRICTLY:\n#{custom}\n" : ""
      rescue StandardError
        ""
      end

      def self.call(question, embeddings, history: [], few_shot_examples: [])
        Glancer::Utils::Logger.info("Workflow::PromptBuilder", "Building prompt for question: #{question.inspect}")

        now = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        adapter = Glancer.configuration.resolved_adapter
        db_name = begin
          ActiveRecord::Base.connection.current_database
        rescue StandardError
          "unknown"
        end

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Current time: #{now}, Adapter: #{adapter}, DB: #{db_name}")

        history_context = history.map do |msg|
          if msg.role == "assistant" && msg.sql.present?
            "ASSISTANT (SQL used): #{msg.sql.strip}\nASSISTANT (response): #{msg.content}"
          else
            "#{msg.role.upcase}: #{msg.content}"
          end
        end.join("\n\n")

        schema_context, fk_context = partition_embeddings(embeddings)
        examples_context = format_few_shot_examples(few_shot_examples)

        prompt = <<~PROMPT
          Current datetime: #{now}
          Active Database Adapter: #{adapter}
          Database Name: #{db_name}

          You are a specialized Ruby on Rails SQL expert.
          Your only task is to generate a valid SQL SELECT statement based on the provided DATABASE CONTEXT.

          STRICT GUIDELINES:
          1. **Output**: Return ONLY the SQL query. No explanation, no reasoning text, no markdown prose — just the SQL.
          2. **No Translations**: NEVER translate table names or column names. Use names EXACTLY as they appear in the schema.
          3. **SELECT Only**: Only generate SELECT or WITH (CTE) statements. Destructive operations are strictly forbidden.
          4. **Joins**: Use the SCHEMA RELATIONSHIPS section below to determine correct JOIN conditions.
          5. **Formatting**: Format SQL with proper indentation and line breaks:
             - Each major clause (SELECT, FROM, WHERE, JOIN, GROUP BY, ORDER BY, HAVING, LIMIT) on its own line.
             - Indent selected columns, JOIN conditions, and WHERE predicates with 2 spaces.
             - Use a new line for each selected column when there are more than 2 columns.

          Think through the query internally before writing it, but your final response must contain SQL only — no surrounding text.

          Rules for generation:
          - Use **column aliases (AS ...)** to improve readability.
          - The SQL must be valid and executable for #{adapter.to_s.upcase}.
          - Always qualify column names with the table name (e.g., `orders.created_at`).

          SCHEMA RELATIONSHIPS:
          #{fk_context.presence || "(no foreign keys indexed)"}

          #{examples_context.present? ? "EXAMPLE QUERIES (from this database):\n#{examples_context}\n" : ""}
          CONVERSATION HISTORY:
          #{history_context.presence || "(no prior messages)"}

          DATABASE CONTEXT:
          #{format_embeddings_with_stats(schema_context)}

          #{custom_instructions_block}
          NEW QUESTION:
          #{question}

          OUTPUT SQL ONLY:
        PROMPT

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Prompt constructed successfully")

        prompt
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::PromptBuilder", "Failed to build prompt: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error, "Prompt construction failed: #{e.message}"
      end

      def self.example_sql(adapter)
        case adapter.to_s
        when "mysql", "mysql2"
          <<~SQL
            SELECT
              DATE_FORMAT(created_at, '%Y-%m') AS mes,
              COUNT(*) AS total_vendas
            FROM
              vendas
            WHERE
              YEAR(created_at) = 2025
            GROUP BY
              mes
            ORDER BY
              mes;
          SQL
        when "postgres", "postgresql"
          <<~SQL
            SELECT
              TO_CHAR(created_at, 'YYYY-MM') AS mes,
              COUNT(*) AS total_vendas
            FROM
              vendas
            WHERE
              EXTRACT(YEAR FROM created_at) = 2025
            GROUP BY
              mes
            ORDER BY
              mes;
          SQL
        else
          "-- Example not available for this adapter."
        end
      end

      def self.partition_embeddings(embeddings)
        fk_embeds = embeddings.select { |e| e.source_path.to_s.end_with?("#foreign_keys") }
        other_embeds = embeddings.reject { |e| e.source_path.to_s.end_with?("#foreign_keys") }
        fk_text = fk_embeds.map { |e| e.content.strip }.join("\n")
        [other_embeds, fk_text]
      end

      def self.format_embeddings_with_stats(embeddings)
        embeddings.map { |embed| embed.content.strip }.join("\n\n")
      end

      def self.format_few_shot_examples(examples)
        return "" if examples.blank?

        examples.each_with_index.map do |(question, sql), i|
          "Example #{i + 1}:\nQuestion: #{question}\nSQL: #{sql.strip}"
        end.join("\n\n")
      end
    end
  end
end
