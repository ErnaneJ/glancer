module Glancer
  module Workflow
    class PromptBuilder
      def self.call(question, context_chunks)
        Glancer::Utils::Logger.info("Workflow::PromptBuilder", "Building prompt for question: #{question.inspect}")

        now = Time.current.strftime("%Y-%m-%d %H:%M:%S")
        adapter = Glancer.configuration.adapter

        Glancer::Utils::Logger.debug("Workflow::PromptBuilder", "Current time: #{now}, Adapter: #{adapter}")

        prompt = <<~PROMPT
          Current datetime: #{now}
          Active Database Adapter: #{adapter}

          You are a Ruby on Rails assistant with access to the application's database schema.

          Your task is to generate the most simple, correct, and safe SQL query possible based solely on the schema and the user's question.

          Rules:
          - Only generate **SELECT** statements
          - Never use destructive queries (DELETE, UPDATE, etc)
          - Use **column aliases (AS ...)** to improve readability
          - The SQL must be valid and executable
          - Do **not** return explanations or comments
          - Respect the language used in the user question
          - If the query involves time grouping (e.g., sales per month), include **all periods**, even with zero results
          - Always specify the table name for each column (e.g., `user.name`, not just `name`), even when the table is unambiguous.

          VERY IMPORTANT:
          You MUST generate SQL that is compatible with #{adapter.upcase}.
          NEVER use functions exclusive to other databases.
          For example:
          - Do NOT use `STRFTIME` (SQLite) in MySQL;
          - Use `DATE_FORMAT(created_at, '%Y-%m')` in MySQL;
          - Use `TO_CHAR(created_at, 'YYYY-MM')` in PostgreSQL.

          Example (for #{adapter.upcase}):
          Question: Quantas vendas por mês tivemos em 2025?

          SQL:
          #{example_sql(adapter)}

          CONTEXT:
          #{context_chunks.join("\n\n")}

          QUESTION:
          #{question}

          OUTPUT:
          SQL only:
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
    end
  end
end
