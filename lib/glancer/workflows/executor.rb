module Glancer
  module Workflows
    class Executor
      def initialize(question)
        @question = question
      end

      def call
        sql = SQLGenerator.new(@question).call

        unless sql.strip.downcase.start_with?("select")
          raise Glancer::Error, "Only SELECT queries are allowed for execution"
        end

        puts("[Glancer::Executor] Executing question: #{@question.inspect}")
        result = execute_sql(sql)

        {
          sql: sql,
          result: result
        }
      end

      private

      def execute_sql(sql)
        ActiveRecord::Base.connection.exec_query(sql).to_a # @TODO read_only_db
      rescue StandardError => e
        raise Glancer::Error, "Failed to execute SQL: #{e.message}"
      end
    end
  end
end
