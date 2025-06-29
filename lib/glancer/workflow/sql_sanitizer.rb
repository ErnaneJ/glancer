module Glancer
  module Workflow
    class SQLSanitizer
      FORBIDDEN_KEYWORDS = %w[
        delete update insert drop truncate alter create replace
      ].freeze

      def self.ensure_safe!(sql)
        Glancer::Utils::Logger.info("Workflow::SQLSanitizer", "Sanitizing SQL...")

        cleaned = strip_strings_and_comments(sql.downcase)
        Glancer::Utils::Logger.debug("Workflow::SQLSanitizer", "Sanitized SQL for inspection:\n#{cleaned}")

        forbidden = FORBIDDEN_KEYWORDS.find { |kw| cleaned.match?(/\b#{kw}\b/) }

        if forbidden
          Glancer::Utils::Logger.error("Workflow::SQLSanitizer", "Blocked SQL due to forbidden keyword: '#{forbidden}'")
          raise Glancer::Error, "Query blocked due to forbidden keyword: '#{forbidden}' in SQL: #{sql.inspect}"
        end

        Glancer::Utils::Logger.info("Workflow::SQLSanitizer", "SQL passed sanitization check.")
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::SQLSanitizer", "Sanitization failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::SQLSanitizer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("SQL sanitization failed: #{e.message}"), cause: e
      end

      def self.strip_strings_and_comments(sql)
        # Remove strings: '...', allowing escaped quotes
        sql = sql.gsub(/'(?:\\'|[^'])*'/, "")

        # Remove inline comments -- ...
        sql = sql.gsub(/--.*/, "")

        # Remove block comments /* ... */
        sql.gsub(%r{/\*.*?\*/}m, "")
      end
    end
  end
end
