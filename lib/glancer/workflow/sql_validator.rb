module Glancer
  module Workflow
    class SQLValidator
      def self.validate_tables_exist!(sql)
        tables_in_sql = extract_table_names(sql)
        indexed_tables = indexed_schema_table_names

        missing = tables_in_sql - indexed_tables

        return unless missing.any?

        raise Glancer::Error, "Missing table(s) in indexed schema: #{missing.join(", ")}"
      end

      def self.extract_table_names(sql)
        sql.scan(/\bfrom\s+([a-zA-Z0-9_]+)/i).flatten.map(&:downcase).uniq
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
    end
  end
end
