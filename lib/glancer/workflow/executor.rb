module Glancer
  module Workflow
    class Executor
      def self.execute(sql)
        unless sql.strip.downcase.start_with?("select")
          raise Glancer::Error,
                "Only SELECT queries are allowed for execution"
        end

        puts("[Glancer::Executor] Executing SQL: #{sql.inspect}")
        connection = read_only_connection || ActiveRecord::Base.connection
        connection.exec_query(sql).to_a
      rescue StandardError => e
        raise Glancer::Error, "SQL execution failed: #{e.message}"
      end

      def self.read_only_connection
        return nil unless Glancer.configuration.read_only_db

        ActiveRecord::Base.establish_connection(Glancer.configuration.read_only_db).connection
      rescue StandardError => e
        puts("[Glancer::Executor] Read-only connection failed: #{e.message}")
        nil
      end
    end
  end
end
