module Glancer
  module Workflow
    class SQLExtractor
      def self.extract(text)
        if text =~ /```sql\s*(.*?)\s*```/m
          ::Regexp.last_match(1).strip
        else
          text.lines.map(&:strip)
              .reject(&:empty?)
              .join(" ")
        end
      end
    end
  end
end
