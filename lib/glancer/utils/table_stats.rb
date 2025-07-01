module Glancer
  module Utils
    module TableStats
      module_function

      def count_for(table_name)
        return -1 unless Glancer::Configuration.valid_table_name?(table_name)

        ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table_name}").to_i
      rescue StandardError => e
        Glancer::Utils::Logger.warn("TableStats", "Could not count rows in #{table_name}: #{e.message}")
        -1
      end
    end
  end
end
