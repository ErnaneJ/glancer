module Glancer
  module Workflow
    class SQLExtractor
      SQL_START = /\A\s*(select|with|explain)\b/i

      def self.extract(text)
        Glancer::Utils::Logger.info("Workflow::SQLExtractor", "Extracting SQL from text response...")

        # Match ```sql, ```SQL, or plain ``` fenced blocks
        if text =~ /```(?:sql)?\s*\n?(.*?)\s*```/mi
          sql = ::Regexp.last_match(1).strip
          Glancer::Utils::Logger.debug("Workflow::SQLExtractor", "Extracted SQL from formatted code block.")
        else
          # Fallback: find the first line that looks like the start of a SQL statement
          # and take everything from there, ignoring leading explanation text.
          lines = text.lines
          start_idx = lines.index { |l| l.strip.match?(SQL_START) }

          sql = if start_idx
                  lines[start_idx..].join.strip
                else
                  text.lines.map(&:strip).reject(&:empty?).join(" ")
                end

          Glancer::Utils::Logger.debug("Workflow::SQLExtractor",
                                       "No code block found. Fallback extraction#{start_idx ? " (SQL found at line #{start_idx})" : " (raw join)"}.")
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
