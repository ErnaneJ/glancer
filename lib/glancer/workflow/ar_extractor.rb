# frozen_string_literal: true

module Glancer
  module Workflow
    class ARExtractor
      def self.extract(text)
        Glancer::Utils::Logger.info("Workflow::ARExtractor", "Extracting Ruby expression from LLM response...")

        code = if text =~ /```(?:ruby)?\s*\n?(.*?)\s*```/mi
                 Glancer::Utils::Logger.debug("Workflow::ARExtractor", "Extracted from code block.")
                 ::Regexp.last_match(1).strip
               else
                 Glancer::Utils::Logger.debug("Workflow::ARExtractor", "No code block found, using raw text.")
                 text.strip
               end

        Glancer::Utils::Logger.debug("Workflow::ARExtractor", "Extracted expression:\n#{code}")
        code
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::ARExtractor", "Extraction failed: #{e.message}")
        raise Glancer::Error, "AR code extraction failed: #{e.message}"
      end
    end
  end
end
