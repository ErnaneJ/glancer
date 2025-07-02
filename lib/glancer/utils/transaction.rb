module Glancer
  module Utils
    class Transaction
      def self.make(&block)
        original_config = ActiveRecord::Base.connection_db_config
        connection = read_only_connection || ActiveRecord::Base.connection

        Glancer::Utils::Logger.info("Utils::Transaction",
                                    "Using \e[1;33m#{connection_config_name(connection)}\e[36m connection for query execution.")

        connection.transaction { yield(connection) }
      rescue StandardError => e
        Glancer::Utils::Logger.error("Utils::Transaction", "An error occurred: #{e.message}")
        raise
      ensure
        ActiveRecord::Base.establish_connection(original_config) if read_only_connection_used?

        if defined?(connection) && connection&.transaction_open?
          Glancer::Utils::Logger.warn("Utils::Transaction",
                                      "Transaction was not closed properly. Please check your code.")
        else
          Glancer::Utils::Logger.info("Utils::Transaction", "Transaction completed successfully.")
        end
      end

      def self.read_only_connection
        return nil unless Glancer.configuration.read_only_db

        Glancer::Utils::Logger.info("Utils::Transaction", "Establishing connection to read-only database...")

        @used_read_only = true

        connection = ActiveRecord::Base.establish_connection(Glancer.configuration.read_only_db).connection

        Glancer::Utils::Logger.info("Utils::Transaction", "Read-only database connection established successfully.")
        connection
      rescue StandardError => e
        Glancer::Utils::Logger.error("Utils::Transaction",
                                     "Failed to connect to read-only database: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Utils::Transaction", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Read-only DB connection failed: #{e.message}"), cause: e
      end

      def self.read_only_connection_used?
        value = @used_read_only
        @used_read_only = false # reset
        value
      end

      def self.connection_config_name(connection)
        connection.pool.db_config.name
      rescue StandardError
        "unknown"
      end
    end
  end
end
