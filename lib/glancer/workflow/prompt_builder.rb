module Glancer
  module Workflow
    class PromptBuilder
      def self.call(question, embeddings, history: [])
        Glancer::Utils::Logger.info("Workflow::PromptBuilder", "Building prompt for question: #{question.inspect}")

        now = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        adapter = Glancer.configuration.adapter

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Current time: #{now}, Adapter: #{adapter}")

        history_context = history.map do |msg|
          "#{msg.role.upcase}: #{msg.content}"
        end.join("\n")

        prompt = <<~PROMPT
          Current datetime: #{now}
          Active Database Adapter: #{adapter}

          You are a specialized Ruby on Rails SQL expert.#{" "}
          Your only task is to generate a valid SQL SELECT statement based on the provided DATABASE CONTEXT.

          STRICT GUIDELINES:
          1. **Language**: You MUST respond in the same language as the "NEW QUESTION". If the question is in Portuguese, your thoughts and explanation must be in Portuguese.
          2. **No Translations**: NEVER translate table names or column names. If the context shows a table named "clientes", do NOT use "clients". Use names EXACTLY as they appear in the schema.
          3. **SELECT Only**: Only generate SELECT statements. Destructive operations are strictly forbidden.
          4. **Joins**: Use the relationships described in the context to join tables.

          Rules for generation:
          - Use **column aliases (AS ...)** to improve readability.
          - The SQL must be valid and executable for #{adapter.upcase}.
          - Do **not** return explanations or comments.
          - Always specify the table name for each column (e.g., `clientes.nome`).
          - Respect the language used in the user question.

          CONVERSATION HISTORY:
          #{history_context}

          DATABASE CONTEXT:
          #{format_embeddings_with_stats(embeddings)}

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

      def self.format_embeddings_with_stats(embeddings)
        embeddings.map do |embed|
          content = embed.content.strip

          if embed.source_type == "schema" && embed.source_path =~ /#(\w+)$/
            table_name = Regexp.last_match(1)
            count = -1 # Glancer::Utils::TableStats.count_for(table_name)
            stats = count >= 0 ? "Table '#{table_name}' contains approximately #{count} record(s).\n" : ""
            "#{stats}#{content}"
          else
            content
          end
        end.join("\n\n")
      end
    end
  end
end
