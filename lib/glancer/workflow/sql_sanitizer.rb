module Glancer
  module Workflow
    class SQLSanitizer
      FORBIDDEN_KEYWORDS = %w[
        delete update insert drop truncate alter create replace
      ].freeze

      def self.ensure_safe!(sql)
        cleaned = strip_strings_and_comments(sql.downcase)
        return unless FORBIDDEN_KEYWORDS.any? { |kw| cleaned.match?(/\b#{kw}\b/) }

        raise Glancer::Error, "Query blocked due to forbidden keywords: '#{sql}'"
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
