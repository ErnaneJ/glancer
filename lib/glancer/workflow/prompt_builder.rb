module Glancer
  module Workflow
    class PromptBuilder
      def self.call(question, embeddings, history: [], few_shot_examples: [])
        Glancer::Utils::Logger.info("Workflow::PromptBuilder", "Building prompt for question: #{question.inspect}")

        now = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        adapter = Glancer.configuration.resolved_adapter

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Current time: #{now}, Adapter: #{adapter}")

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

          You are a specialized Ruby on Rails SQL expert.
          Your only task is to generate a valid SQL SELECT statement based on the provided DATABASE CONTEXT.

          STRICT GUIDELINES:
          1. **Language**: You MUST respond in the same language as the "NEW QUESTION". If the question is in Portuguese, respond in Portuguese.
          2. **No Translations**: NEVER translate table names or column names. Use names EXACTLY as they appear in the schema.
          3. **SELECT Only**: Only generate SELECT statements. Destructive operations are strictly forbidden.
          4. **Joins**: Use the SCHEMA RELATIONSHIPS section below to determine correct JOIN conditions.
          5. **Reasoning**: Before writing SQL, reason step by step: (1) identify relevant tables, (2) determine required joins using the foreign keys, (3) confirm column names exist in the schema.

          Rules for generation:
          - Use **column aliases (AS ...)** to improve readability.
          - The SQL must be valid and executable for #{adapter.to_s.upcase}.
          - Do **not** return explanations or comments.
          - Always qualify column names with the table name (e.g., `orders.created_at`).

          SCHEMA RELATIONSHIPS:
          #{fk_context.presence || "(no foreign keys indexed)"}

          #{examples_context.present? ? "EXAMPLE QUERIES (from this database):\n#{examples_context}\n" : ""}
          CONVERSATION HISTORY:
          #{history_context.presence || "(no prior messages)"}

          DATABASE CONTEXT:
          #{format_embeddings_with_stats(schema_context)}

          NEW QUESTION:
          #{question}

          OUTPUT SQL ONLY:
        PROMPT

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Prompt constructed successfully")

        prompt
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::PromptBuilder", "Failed to build prompt: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Prompt construction failed: #{e.message}"), cause: e
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
