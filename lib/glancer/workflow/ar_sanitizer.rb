# frozen_string_literal: true

module Glancer
  module Workflow
    class ARSanitizer
      # Destructive ActiveRecord methods
      FORBIDDEN_AR_METHODS = %w[
        destroy destroy_all
        delete delete_all
        update update! update_all update_columns update_column
        save save!
        create create! create_or_find_by create_or_find_by!
        insert insert_all insert_all!
        upsert upsert_all
        touch toggle! increment! decrement! increment_counter decrement_counter
      ].freeze

      # Shell / OS execution
      SHELL_PATTERNS = [
        /\bsystem\s*[\[(]/,
        /`[^`]+`/,
        /\bexec\s*\(/,
        /\bspawn\s*\(/,
        /\bOpen3\b/,
        /\bIO\.popen\b/,
        /\bKernel\s*\.\s*system\b/
      ].freeze

      # Dynamic code execution
      EVAL_PATTERNS = [
        /\beval\s*\(/,
        /\binstance_eval\b/,
        /\bclass_eval\b/,
        /\bmodule_eval\b/,
        /\bBinding\b/
      ].freeze

      # File system writes
      FILE_WRITE_PATTERNS = [
        /\bFileUtils\b/,
        /\bFile\s*\.\s*(?:write|binwrite|open)\b/,
        /\bIO\s*\.\s*(?:write|binwrite)\b/
      ].freeze

      # Dynamic loading
      LOAD_PATTERNS = [
        /\brequire(?:_relative)?\s*["'(]/,
        /\bload\s*["'(]/,
        /\bautoload\b/
      ].freeze

      def self.ensure_safe!(code)
        Glancer::Utils::Logger.info("Workflow::ARSanitizer", "Sanitizing ActiveRecord expression...")

        FORBIDDEN_AR_METHODS.each do |method|
          # \b after the method name ensures we don't block e.g. .creates_table or .destroy_later
          if code.match?(/\.#{Regexp.escape(method)}\b/)
            raise Glancer::Error,
                  "ActiveRecord expression blocked: forbidden write method '.#{method}'"
          end
        end

        SHELL_PATTERNS.each do |pattern|
          raise Glancer::Error, "ActiveRecord expression blocked: shell execution detected" if code.match?(pattern)
        end

        EVAL_PATTERNS.each do |pattern|
          raise Glancer::Error, "ActiveRecord expression blocked: dynamic eval detected" if code.match?(pattern)
        end

        FILE_WRITE_PATTERNS.each do |pattern|
          raise Glancer::Error, "ActiveRecord expression blocked: file write detected" if code.match?(pattern)
        end

        LOAD_PATTERNS.each do |pattern|
          raise Glancer::Error, "ActiveRecord expression blocked: dynamic load detected" if code.match?(pattern)
        end

        Glancer::Utils::Logger.info("Workflow::ARSanitizer", "Expression passed sanitization check.")
      rescue Glancer::Error
        raise
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::ARSanitizer", "Sanitization failed: #{e.message}")
        raise Glancer::Error, "AR sanitization failed: #{e.message}"
      end
    end
  end
end
