module Glancer
  module Workflow
    class SQLExtractor
      def self.extract(text)
        Glancer::Utils::Logger.info("Workflow::SQLExtractor", "Extracting SQL from text response...")

        if text =~ /```sql\s*(.*?)\s*```/m
          sql = ::Regexp.last_match(1).strip
          Glancer::Utils::Logger.debug("Workflow::SQLExtractor", "Extracted SQL from formatted code block.")
        else
          sql = text.lines.map(&:strip).reject(&:empty?).join(" ")
          Glancer::Utils::Logger.debug("Workflow::SQLExtractor",
                                       "No code block found. Fallback to line-by-line extraction.")
        end

        Glancer::Utils::Logger.debug("Workflow::SQLExtractor", "Final extracted SQL:\n#{sql}")

        sql
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::SQLExtractor", "SQL extraction failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Workflow::SQLExtractor", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("SQL extraction failed: #{e.message}"), cause: e
      end
    end
  end
end
