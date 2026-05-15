# frozen_string_literal: true

module Glancer
  module Workflow
    class Executor
      def self.execute(sql, original_question: nil, attempt: 1, message_id: nil)
        # Security check: Ensure only read queries are executed (SELECT or CTEs starting with WITH)
        unless sql.strip.match?(/\A\s*(select|with)\b/i)
          Glancer::Utils::Logger.error("Workflow::Executor", "Blocked attempt to run non-SELECT SQL.")
          raise Glancer::Error, "Only SELECT queries are allowed for execution."
        end

        Glancer::Utils::Logger.info("Workflow::Executor", "Executing SQL (Attempt ##{attempt})...")

        run_id = SecureRandom.uuid
        # Appending a comment for easier database auditing
        sql_with_comment = "#{sql.strip} /*glancer,run_id:#{run_id}*/"

        begin
          result = nil
          Glancer::Utils::Transaction.make do |connection|
            apply_statement_timeout(connection)
            result = connection.exec_query(sql_with_comment).to_a
            raise ActiveRecord::Rollback
          end

          # Audit successful execution
          Glancer::Audit.create!(
            question: original_question,
            sql: sql_with_comment,
            adapter: Glancer.configuration.resolved_adapter,
            run_id: run_id,
            executed_at: Time.current,
            message_id: message_id
          )

          result
        rescue StandardError => e
          # Stop recursion if we reached the maximum number of attempts (3)
          if attempt >= 3
            Glancer::Utils::Logger.error("Workflow::Executor", "Final failure after #{attempt} attempts: #{e.message}")
            return { error: true, message: e.message, last_sql: sql }
          end

          Glancer::Utils::Logger.warn("Workflow::Executor",
                                      "SQL Error (Attempt ##{attempt}): #{e.message}. Requesting correction...")

          # Invoke the Builder to analyze the error and fix the SQL
          fixed_sql = Glancer::Workflow::Builder.fix_sql(sql, e.message)

          # Retry execution with the corrected SQL
          execute(fixed_sql, original_question: original_question, attempt: attempt + 1, message_id: message_id)
        end
      end

      def self.apply_statement_timeout(connection)
        timeout_ms = Glancer.configuration.statement_timeout.to_i * 1000
        adapter = Glancer.configuration.resolved_adapter.to_s

        case adapter
        when "postgres", "postgresql"
          connection.execute("SET statement_timeout = #{timeout_ms}")
        when "mysql", "mysql2"
          connection.execute("SET max_execution_time = #{timeout_ms}")
        end
      rescue StandardError => e
        Glancer::Utils::Logger.warn("Workflow::Executor", "Could not set statement timeout: #{e.message}")
      end
    end
  end
end
