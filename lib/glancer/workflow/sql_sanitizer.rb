module Glancer
  module Workflow
    class SQLSanitizer
      FORBIDDEN_KEYWORDS = %w[
        delete update insert drop truncate alter create replace
      ].freeze

      def self.safe?(sql)
        downcased = sql.downcase
        FORBIDDEN_KEYWORDS.none? { |kw| downcased.include?(kw) }
      end

      def self.ensure_safe!(sql)
        raise Glancer::Error, "Query blocked due to forbidden keywords" unless safe?(sql)
      end
    end
  end
end
