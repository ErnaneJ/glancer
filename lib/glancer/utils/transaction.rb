module Glancer
  module Utils
    class Transaction
      def self.with_transaction(&block)
        if ActiveRecord::Base.connection.transaction_open?
          yield
        else
          ActiveRecord::Base.transaction(&block)
        end
      rescue StandardError => e
        Glancer::Utils::Logger.error("Utils::Transaction", "An error occurred: #{e.message}")
        raise e
      ensure
        if ActiveRecord::Base.connection.transaction_open?
          Glancer::Utils::Logger.warn("Utils::Transaction",
                                      "Transaction was not closed properly. Please check your code.")
        else
          Glancer::Utils::Logger.info("Utils::Transaction", "Transaction completed successfully.")
        end
      end
    end
  end
end
