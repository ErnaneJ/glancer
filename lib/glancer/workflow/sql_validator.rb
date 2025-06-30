module Glancer
  module Workflow
    class SQLValidator
      def self.validate_tables_exist!(sql)
        Glancer::Utils::Logger.info("Workflow::SQLValidator", "Validating presence of tables in indexed schema...")

        tables_in_sql = extract_table_names(sql)
        Glancer::Utils::Logger.debug("Workflow::SQLValidator", "Tables found in SQL: #{tables_in_sql.inspect}")

        indexed_tables = indexed_schema_table_names
        Glancer::Utils::Logger.debug("Workflow::SQLValidator",
                                     "Tables available in indexed schema: #{indexed_tables.inspect}")

        missing = tables_in_sql.reject do |table|
          system_table?(table) || indexed_tables.include?(table)
        end

        if missing.any?
          Glancer::Utils::Logger.error("Workflow::SQLValidator", "Missing table(s): #{missing.join(", ")}")
          raise Glancer::Error, "Missing table(s) in indexed schema: #{missing.join(", ")}"
        end

        Glancer::Utils::Logger.info("Workflow::SQLValidator", "All referenced tables are present in indexed schema.")
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::SQLValidator", "Table validation failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::SQLValidator", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Table validation failed: #{e.message}"), cause: e
      end

      def self.extract_table_names(sql)
        sql.scan(/\bfrom\s+([a-zA-Z0-9_."]+)/i).flatten.map do |name|
          name.gsub('"', "").downcase.strip
        end.uniq
      end

      def self.system_table?(table_name)
        schema = table_name.include?(".") ? table_name.split(".").first.downcase : table_name
        system_schemas.include?(schema)
      end

      def self.indexed_schema_table_names
        Glancer::Embedding
          .where(source_type: "schema")
          .pluck(:source_path)
          .map { |path| path[/#(.*?)\z/, 1] }
          .compact
          .map(&:downcase)
          .uniq
      end

      def self.system_schemas
        case Glancer.configuration.adapter.to_s
        when "postgres", "postgresql"
          %w[information_schema pg_catalog pg_toast]
        when "mysql", "mysql2"
          %w[information_schema mysql performance_schema sys]
        when "sqlite", "sqlite3"
          %w[sqlite_master]
        else
          []
        end
      end
    end
  end
end
