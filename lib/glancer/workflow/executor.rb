module Glancer
  module Workflow
    class Executor
      def self.execute(sql)
        unless sql.strip.downcase.start_with?("select")
          Glancer::Utils::Logger.error("Workflow::Executor", "Blocked attempt to run non-SELECT SQL: #{sql.inspect}")
          raise Glancer::Error, "Only SELECT queries are allowed for execution. Provided query: #{sql.strip}"
        end

        Glancer::Utils::Logger.info("Workflow::Executor", "Preparing to execute SQL query...")
        Glancer::Utils::Logger.debug("Workflow::Executor", "SQL Statement:\n#{sql}")

        connection = read_only_connection || ActiveRecord::Base.connection

        Glancer::Utils::Logger.info("Workflow::Executor",
                                    "Using #{connection_config_name(connection)} connection for query execution.")

        result = connection.exec_query(sql).to_a

        Glancer::Utils::Logger.info("Workflow::Executor",
                                    "SQL query executed successfully. Rows returned: #{result.size}")
        Glancer::Utils::Logger.debug("Workflow::Executor", "Sample result row: #{result.first.inspect}") if result.any?

        result
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Executor", "SQL execution failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Executor", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("SQL execution failed: #{e.message}"), cause: e
      end

      def self.read_only_connection
        return nil unless Glancer.configuration.read_only_db

        Glancer::Utils::Logger.info("Workflow::Executor", "Establishing connection to read-only database...")

        conn = ActiveRecord::Base.establish_connection(Glancer.configuration.read_only_db).connection

        Glancer::Utils::Logger.info("Workflow::Executor", "Read-only database connection established successfully.")

        conn
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::Executor",
                                     "Failed to connect to read-only database: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::Executor", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Read-only DB connection failed: #{e.message}"), cause: e
      end

      def self.connection_config_name(connection)
        connection.pool.db_config.name
      rescue StandardError
        "unknown"
      end
    end
  end
end
