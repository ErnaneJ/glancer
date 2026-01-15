module Glancer
  module Workflow
    class Executor
      def self.execute(sql, original_question: nil, attempt: 1)
        # Security check: Ensure only SELECT queries are executed
        unless sql.strip.downcase.start_with?("select")
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
            # Execute the query and convert the ActiveRecord::Result to an Array of Hashes
            result = connection.exec_query(sql_with_comment).to_a
            # Always rollback to ensure data integrity during read-only operations
            raise ActiveRecord::Rollback
          end

          # Audit successful execution
          Glancer::Audit.create!(
            question: original_question,
            sql: sql_with_comment,
            adapter: Glancer.configuration.adapter,
            run_id: run_id,
            executed_at: Time.current
          )

          result
        rescue StandardError => e
          # Stop recursion if we reached the maximum number of attempts (3)
          if attempt >= 3
            Glancer::Utils::Logger.error("Workflow::Executor", "Final failure after #{attempt} attempts: #{e.message}")
            raise Glancer::Error.new("Failed to generate a valid SQL after multiple attempts: #{e.message}")
          end

          Glancer::Utils::Logger.warn("Workflow::Executor",
                                      "SQL Error (Attempt ##{attempt}): #{e.message}. Requesting correction...")

          # Invoke the Builder to analyze the error and fix the SQL
          fixed_sql = Glancer::Workflow::Builder.fix_sql(sql, e.message)

          # Retry execution with the corrected SQL
          execute(fixed_sql, original_question: original_question, attempt: attempt + 1)
        end
      end
    end
  end
end
