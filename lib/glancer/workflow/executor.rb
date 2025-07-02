module Glancer
  module Workflow
    class Executor
      def self.execute(sql, original_question: nil)
        unless sql.strip.downcase.start_with?("select")
          Glancer::Utils::Logger.error("Workflow::Executor", "Blocked attempt to run non-SELECT SQL: #{sql.inspect}")
          raise Glancer::Error, "Only SELECT queries are allowed for execution. Provided query: #{sql.strip}"
        end

        Glancer::Utils::Logger.info("Workflow::Executor", "Preparing to execute SQL query...")
        Glancer::Utils::Logger.debug("Workflow::Executor", "SQL Statement:\n#{sql}")

        run_id = SecureRandom.uuid
        sql_with_comment = "#{sql.strip} /*glancer,run_id:#{run_id}*/"

        result = nil
        Glancer::Utils::Transaction.make do |connection| # for safety
          result = connection.exec_query(sql_with_comment).to_a
          raise ActiveRecord::Rollback # force rollback to avoid committing any changes
        end

        Glancer::Audit.create!(
          question: original_question,
          sql: sql_with_comment,
          adapter: Glancer.configuration.adapter,
          run_id: run_id,
          executed_at: Time.current
        )

        Glancer::Utils::Logger.info("Workflow::Executor",
                                    "SQL query executed successfully. Rows returned: #{result.size}")
        Glancer::Utils::Logger.debug("Workflow::Executor", "Sample result row: #{result.first.inspect}") if result.any?

        result
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Executor", "SQL execution failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Executor", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("SQL execution failed: #{e.message}"), cause: e
      end
    end
  end
end
